// ignore_for_file: use_null_aware_elements

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:waslny_captain/core/network/api_exceptions.dart';
import 'package:waslny_captain/core/network/dio_client.dart';
import 'package:waslny_captain/core/models/ride_model.dart';
import 'package:waslny_captain/core/utils/logger.dart';

/// HTTP API client for communicating with the Waslny Backend API.
///
/// Handles authentication via JWT token stored in memory.
/// In production, use [shared_preferences] or [flutter_secure_storage]
/// for persistent token storage across app restarts.
class ApiService {
  static final ApiService instance = ApiService._();
  ApiService._();

  // Change this to your production URL when deploying
  static const String _baseUrl =
      'https://wasalny-backend-production.up.railway.app/api/v1';

  /// Public base URL used by other services (e.g. [ImageUploadService]).
  static String get baseUrl => _baseUrl;

  /// Toggle the custom backend API on/off.
  ///
  /// Set to `false` to run the app entirely on Firebase + Firestore
  /// (no custom Node.js/Express backend required). When `false`, every
  /// [ApiService] request returns a safe default instead of hitting the
  /// network, so the app never shows "فشل الاتصال بالخادم".
  ///
  /// Set to `true` once your backend server is running and reachable.
  static const bool backendEnabled = true;

  String? _token;

  /// Local-storage key under which the JWT is persisted so it survives app
  /// restarts (avoids 401 on cold start before the user re-logs in).
  static const String _tokenStorageKey = 'api_jwt_token';

  // ── Token Management ─────────────────────────────────

  void saveToken(String token) {
    _token = token;
    _persistToken(token);
  }

  /// Persists the JWT to local storage (fire-and-forget, never blocks UI).
  Future<void> _persistToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenStorageKey, token);
    } catch (e) {
      logError('ApiService', 'saveToken persist failed: $e', e);
    }
  }

  /// Restores the persisted JWT into memory. Call once during app startup
  /// (e.g. from the splash screen) so authenticated requests work even
  /// before the user explicitly re-authenticates.
  Future<void> loadToken() async {
    if (hasToken) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_tokenStorageKey);
    } catch (e) {
      logError('ApiService', 'loadToken failed: $e', e);
    }
  }

  String? getToken() => _token;

  /// Public wrapper used by other services (e.g. [ImageUploadService])
  /// to make sure a JWT is present in memory before sending an
  /// authenticated request. Restores from local storage if needed.
  Future<void> ensureTokenReady() => _ensureTokenLoaded();

  void clearToken() {
    _token = null;
    _clearPersistedToken();
  }

  Future<void> _clearPersistedToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenStorageKey);
    } catch (e) {
      logError('ApiService', 'clearToken persist failed: $e', e);
    }
  }

  bool get hasToken => _token != null && _token!.isNotEmpty;

  /// Decodes the stored JWT and returns the `userId` claim from its payload,
  /// or `null` if the token is missing / malformed.
  String? get userId {
    if (_token == null) return null;
    try {
      final parts = _token!.split('.');
      if (parts.length != 3) return null;
      // Normalise Base64‑URL → Base64 (padding + URL‑safe chars).
      var payload = parts[1];
      payload = payload.padRight(
        payload.length + (4 - payload.length % 4) % 4,
        '=',
      );
      payload = payload.replaceAll('-', '+').replaceAll('_', '/');
      final decoded = utf8.decode(base64.decode(payload));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      return json['userId'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Ensures a JWT is present in memory before sending an authenticated
  /// request. If the in-memory token is missing (e.g. after a cold start),
  /// it attempts to restore it from local storage to avoid 401 errors.
  Future<void> _ensureTokenLoaded() async {
    if (hasToken) return;
    await loadToken();
  }

  /// Shortcut to the shared Dio instance.
  Dio get _dio => DioClient.instance.dio;

  // ── Auth Endpoints ───────────────────────────────────

  /// Sign in / register via Firebase ID Token.
  ///
  /// Sends the Firebase ID Token (obtained after successful phone OTP
  /// verification) to the backend. The backend verifies the token with
  /// Firebase Admin SDK, looks up / creates the user in PostgreSQL, and
  /// returns the application's own JWT.
  Future<Map<String, dynamic>> signInWithFirebase(
    String firebaseIdToken,
  ) async {
    if (!backendEnabled) return <String, dynamic>{'success': true};
    final response = await _dio.post(
      '/auth/firebase-login',
      data: {'firebaseIdToken': firebaseIdToken},
    );
    final result = response.data as Map<String, dynamic>;
    if (result['token'] != null) {
      saveToken(result['token'] as String);
    }
    return result;
  }

  /// Register / refresh the captain's FCM token on the backend.
  ///
  /// Sends a POST to `/api/v1/auth/register-fcm-token` with the body
  /// `{ "fcmToken": token }`. The backend uses this token to target the
  /// captain with real ride-alert push notifications.
  ///
  /// Returns `true` on success, `false` on failure (network/HTTP error) so the
  /// caller can retry later without crashing the login flow.
  Future<bool> updateFcmTokenToServer(String token) async {
    if (!backendEnabled) return false;
    if (token.isEmpty) return false;
    try {
      await _dio.post('/auth/register-fcm-token', data: {'fcmToken': token});
      logInfo('ApiService', '✅ FCM token registered with backend');
      return true;
    } on DioException catch (e) {
      logWarning(
        'ApiService',
        'updateFcmTokenToServer failed: ${e.response?.statusCode} ${e.response?.data}',
      );
      return false;
    } catch (e) {
      logError('ApiService', 'updateFcmTokenToServer error: $e', e);
      return false;
    }
  }

  /// Register as a driver.
  ///
  /// Sends vehicle info plus optional Google profile data (`name`, `email`,
  /// `photoUrl`) so the backend can create or update the `User` record with
  /// Google account details alongside the driver-specific fields.
  Future<Map<String, dynamic>> registerDriver({
    required String carModel,
    required String carPlateNumber,
    required String carColor,
    required String vehicleType,
    required String carPhotoUrl,
    String? name,
    String? email,
    String? photoUrl,
    String? phoneNumber,
    String? nationalId,
    String? idCardUrl,
    String? idCardBackUrl,
    String? licenseUrl,
    String? licenseBackUrl,
    String? licenseNumber,
    String? vehicleLicenseFrontUrl,
    String? vehicleLicenseBackUrl,
    String? criminalRecordUrl,
    String? drugTestUrl,
  }) async {
    if (!backendEnabled) return <String, dynamic>{'success': true};

    // بناء الـ payload للتأكد من صحة البيانات قبل الإرسال
    final Map<String, dynamic> payload = {
      'role': 'DRIVER',
      'carModel': carModel,
      'carPlateNumber': carPlateNumber,
      'carColor': carColor,
      'vehicleType': vehicleType,
      'carPhotoUrl': carPhotoUrl,
      if (name != null && name.isNotEmpty) 'name': name,
      if (email != null && email.isNotEmpty) 'email': email,
      if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
      if (phoneNumber != null && phoneNumber.isNotEmpty)
        'phoneNumber': phoneNumber,
      if (nationalId != null && nationalId.isNotEmpty) 'nationalId': nationalId,
      if (idCardUrl != null && idCardUrl.isNotEmpty) 'idCardUrl': idCardUrl,
      if (idCardBackUrl != null && idCardBackUrl.isNotEmpty)
        'idCardBackUrl': idCardBackUrl,
      if (licenseUrl != null && licenseUrl.isNotEmpty) 'licenseUrl': licenseUrl,
      if (licenseBackUrl != null && licenseBackUrl.isNotEmpty)
        'licenseBackUrl': licenseBackUrl,
      if (licenseNumber != null && licenseNumber.isNotEmpty)
        'licenseNumber': licenseNumber,
      if (vehicleLicenseFrontUrl != null && vehicleLicenseFrontUrl.isNotEmpty)
        'vehicleLicenseFrontUrl': vehicleLicenseFrontUrl,
      if (vehicleLicenseBackUrl != null && vehicleLicenseBackUrl.isNotEmpty)
        'vehicleLicenseBackUrl': vehicleLicenseBackUrl,
      // الوثائق الاختيارية — تُرسل فقط إذا وفرها الكابتن
      if (criminalRecordUrl != null && criminalRecordUrl.isNotEmpty)
        'criminalRecordUrl': criminalRecordUrl,
      if (drugTestUrl != null && drugTestUrl.isNotEmpty)
        'drugTestUrl': drugTestUrl,
    };

    logInfo('ApiService', 'registerDriver ➡️ payload: ${jsonEncode(payload)}');

    try {
      logInfo(
        'ApiService',
        'registerDriver 🌐 POST ${_dio.options.baseUrl}/auth/register-driver',
      );
      logInfo('ApiService', 'registerDriver 📋 Body: ${jsonEncode(payload)}');
      final response = await _dio.post('/auth/register-driver', data: payload);
      logInfo(
        'ApiService',
        'registerDriver ✅ Response status: ${response.statusCode}',
      );
      logInfo('ApiService', 'registerDriver ✅ Response body: ${response.data}');
      final result = response.data as Map<String, dynamic>;
      if (result['token'] != null) {
        saveToken(result['token'] as String);
      }
      return result;
    } on DioException catch (e) {
      logWarning(
        'ApiService',
        'registerDriver ❌ status ${e.response?.statusCode} | '
            'body: ${e.response?.data} | '
            'request: ${e.requestOptions.data} | '
            'url: ${e.requestOptions.uri} | '
            'type: ${e.type}',
      );
      logWarning(
        'ApiService',
        'registerDriver 🔍 Full error details:\n'
            '  URI: ${e.requestOptions.uri}\n'
            '  Method: ${e.requestOptions.method}\n'
            '  Headers: ${e.requestOptions.headers}\n'
            '  Status: ${e.response?.statusCode}\n'
            '  Response: ${e.response?.data}\n'
            '  DioException type: ${e.type}',
      );
      // إعادة الرمي مع إرفاق رسالة الخطأ من الباك إند لتظهر للمستخدم
      throw ApiException(
        message:
            _extractBackendMessage(e) ??
            'فشل التسجيل في الباك إند (${e.response?.statusCode})',
      );
    }
  }

  /// يستخرج رسالة الخطأ من رد الباك إند.
  String? _extractBackendMessage(DioException e) {
    try {
      final data = e.response?.data;
      if (data == null) return null;
      if (data is String) return data;
      if (data is Map) {
        // محاولة قراءة الحقول المعروفة لرسائل الخطأ
        return (data['message'] ?? data['error'] ?? data['msg'] ?? '')
            .toString();
      }
    } catch (_) {}
    return null;
  }

  /// Updates the captain's phone number on the backend.
  ///
  /// Called when a Google sign-in user needs to provide a real phone number
  /// before completing registration.
  Future<Map<String, dynamic>> updatePhoneNumber({
    required String phoneNumber,
  }) async {
    if (!backendEnabled) return <String, dynamic>{'success': true};

    logInfo('ApiService', 'updatePhoneNumber ➡️ $phoneNumber');

    try {
      final response = await _dio.post(
        '/auth/update-phone',
        data: {'phoneNumber': phoneNumber},
      );
      logInfo(
        'ApiService',
        'updatePhoneNumber ✅ status: ${response.statusCode}',
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      logWarning(
        'ApiService',
        'updatePhoneNumber ❌ status ${e.response?.statusCode} | '
            'body: ${e.response?.data}',
      );
      throw ApiException(
        message:
            _extractBackendMessage(e) ??
            'فشل تحديث رقم الهاتف (${e.response?.statusCode})',
      );
    }
  }

  /// Checks whether the current JWT belongs to a fully‑registered driver on
  /// the backend (i.e. a driverProfile record exists).
  ///
  /// Calls `GET /driver/earnings?period=daily` which returns **200** when the
  /// driver profile exists, or **404** when it does not. Returns `true` only
  /// on a 2xx response; any error (404, 403, timeout, etc.) returns `false`.
  Future<bool> isDriverRegistered() async {
    if (!backendEnabled) return false;
    await _ensureTokenLoaded();
    try {
      final response = await _dio.get(
        '/driver/earnings',
        queryParameters: {'period': 'daily'},
      );
      return response.statusCode != null && response.statusCode! < 300;
    } on DioException catch (e) {
      logWarning(
        'ApiService',
        'isDriverRegistered ❌ ${e.response?.statusCode} ${e.response?.data}',
      );
      return false;
    } catch (e) {
      logError('ApiService', 'isDriverRegistered error: $e', e);
      return false;
    }
  }

  // ── Wallet Endpoints ─────────────────────────────────

  /// Get wallet balance
  Future<Map<String, dynamic>> getWalletBalance() async {
    if (!backendEnabled) return <String, dynamic>{};
    await _ensureTokenLoaded();
    final response = await _dio.get('/wallet/balance');
    return response.data as Map<String, dynamic>;
  }

  /// Get wallet transactions
  Future<Map<String, dynamic>> getWalletTransactions() async {
    if (!backendEnabled) return <String, dynamic>{};
    await _ensureTokenLoaded();
    final response = await _dio.get('/wallet/transactions');
    return response.data as Map<String, dynamic>;
  }

  /// Request a withdrawal.
  /// يدعم التحويل البنكي (BANK) و InstaPay (INSTAPAY).
  /// - للتحويل البنكي: أرسل withdrawMethod='BANK' مع bankName, bankAccount, accountHolder
  /// - لـ InstaPay: أرسل withdrawMethod='INSTAPAY' مع instapayId (مثال: user@instapay)
  Future<Map<String, dynamic>> requestWithdraw({
    required double amount,
    String withdrawMethod = 'BANK',
    String? bankName,
    String? bankAccount,
    String? accountHolder,
    String? instapayId,
    String? walletPhone,
  }) async {
    if (!backendEnabled) return <String, dynamic>{'success': true};
    final data = <String, dynamic>{
      'amount': amount,
      'withdrawMethod': withdrawMethod,
    };
    if (withdrawMethod == 'BANK') {
      data['bankName'] = bankName;
      data['bankAccount'] = bankAccount;
      data['accountHolder'] = accountHolder;
    } else if (withdrawMethod == 'INSTAPAY') {
      data['instapayId'] = instapayId;
    } else if (withdrawMethod == 'WALLET') {
      data['walletPhone'] = walletPhone;
    }
    final response = await _dio.post('/wallet/withdraw', data: data);
    return response.data as Map<String, dynamic>;
  }

  /// Get withdrawal history
  Future<Map<String, dynamic>> getWithdrawals() async {
    if (!backendEnabled) return <String, dynamic>{};
    await _ensureTokenLoaded();
    final response = await _dio.get('/wallet/withdraws');
    return response.data as Map<String, dynamic>;
  }

  /// Top up the wallet via the Kashier payment gateway.
  ///
  /// The backend creates the Kashier session and returns either a
  /// `paymentUrl` to redirect the captain to, or the updated `balance`
  /// when the top-up is applied directly.
  Future<Map<String, dynamic>> topUpWallet({required double amount}) async {
    if (!backendEnabled) return <String, dynamic>{};
    final response = await _dio.post(
      '/wallet/top-up',
      data: {'amount': amount, 'paymentMethod': 'card'},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Initiate a Kashier payment session for wallet top-up.
  ///
  /// Creates a new payment session on the backend and returns the `sessionId`
  /// and `paymentUrl` for use in the in-app WebView checkout.
  Future<Map<String, dynamic>> initiatePayment({
    required double amount,
    String paymentMethod = 'card',
    String? walletPhone,
  }) async {
    if (!backendEnabled) return <String, dynamic>{};
    await _ensureTokenLoaded();
    final data = <String, dynamic>{
      'amount': amount,
      'paymentMethod': paymentMethod,
    };
    if (walletPhone != null) {
      data['walletPhone'] = walletPhone;
    }
    final response = await _dio.post('/wallet/top-up', data: data);
    return response.data as Map<String, dynamic>;
  }

  // ── Payment Methods ──────────────────────────────────

  /// Get all saved payment methods for the current user.
  Future<Map<String, dynamic>> getPaymentMethods() async {
    if (!backendEnabled) return <String, dynamic>{};
    await _ensureTokenLoaded();
    final response = await _dio.get('/wallet/payment-methods');
    return response.data as Map<String, dynamic>;
  }

  /// Add a new payment method (bank / vodafone_cash / instapay).
  Future<Map<String, dynamic>> addPaymentMethod({
    required String type,
    required String label,
    String? accountNumber,
    String? bankName,
  }) async {
    if (!backendEnabled) return <String, dynamic>{'success': true};
    final response = await _dio.post(
      '/wallet/payment-methods',
      data: {
        'type': type,
        'label': label,
        'accountNumber': accountNumber,
        'bankName': bankName,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Delete a saved payment method by its id.
  Future<Map<String, dynamic>> deletePaymentMethod(String id) async {
    if (!backendEnabled) return <String, dynamic>{'success': true};
    await _ensureTokenLoaded();
    final response = await _dio.delete('/wallet/payment-methods/$id');
    return response.data as Map<String, dynamic>;
  }

  /// Set a payment method as the default one.
  Future<Map<String, dynamic>> setDefaultPaymentMethod(String id) async {
    if (!backendEnabled) return <String, dynamic>{'success': true};
    await _ensureTokenLoaded();
    final response = await _dio.put('/wallet/payment-methods/$id/default');
    return response.data as Map<String, dynamic>;
  }

  // ── Driver Endpoints ─────────────────────────────────

  /// Update driver location
  Future<Map<String, dynamic>> updateLocation(double lat, double lng) async {
    if (!backendEnabled) return <String, dynamic>{'success': true};
    final response = await _dio.put(
      '/driver/location',
      data: {'lat': lat, 'lng': lng},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Get available rides nearby
  Future<Map<String, dynamic>> getAvailableRides() async {
    if (!backendEnabled) return <String, dynamic>{};
    final response = await _dio.get('/driver/available-rides');
    return response.data as Map<String, dynamic>;
  }

  /// قبول طلب رحلة (POST). تُرجع true عند النجاح، false عند الفشل.
  Future<bool> acceptRide(String rideId) async {
    if (!backendEnabled) return true;
    try {
      await _dio.post('/driver/accept-ride/$rideId');
      return true;
    } on DioException catch (e) {
      logWarning(
        'ApiService',
        'acceptRide failed: ${e.response?.statusCode} ${e.response?.data}',
      );
      return false;
    } catch (e) {
      logError('ApiService', 'acceptRide error: $e', e);
      return false;
    }
  }

  /// بدء الرحلة (PUT). تُرجع true عند النجاح، false عند الفشل.
  Future<bool> startRide(String rideId) async {
    if (!backendEnabled) return true;
    try {
      await _dio.put('/driver/ride/start/$rideId');
      return true;
    } on DioException catch (e) {
      logWarning(
        'ApiService',
        'startRide failed: ${e.response?.statusCode} ${e.response?.data}',
      );
      return false;
    } catch (e) {
      logError('ApiService', 'startRide error: $e', e);
      return false;
    }
  }

  /// إنهاء الرحلة (PUT). تُرجع true عند النجاح، false عند الفشل.
  Future<bool> completeRide(String rideId) async {
    if (!backendEnabled) return true;
    try {
      await _dio.put('/driver/ride/complete/$rideId');
      return true;
    } on DioException catch (e) {
      logWarning(
        'ApiService',
        'completeRide failed: ${e.response?.statusCode} ${e.response?.data}',
      );
      return false;
    } catch (e) {
      logError('ApiService', 'completeRide error: $e', e);
      return false;
    }
  }

  /// تأكيد وصول الكابتن لنقطة الالتقاط (PUT). تُرجع true عند النجاح، false عند الفشل.
  Future<bool> arriveRide(String rideId) async {
    if (!backendEnabled) return true;
    try {
      await _dio.put('/driver/ride/arrive/$rideId');
      return true;
    } on DioException catch (e) {
      logWarning(
        'ApiService',
        'arriveRide failed: ${e.response?.statusCode} ${e.response?.data}',
      );
      return false;
    } catch (e) {
      logError('ApiService', 'arriveRide error: $e', e);
      return false;
    }
  }

  /// تبديل حالة توافر الكابتن (Online/Offline) في الباك إند.
  /// يُرسل POST إلى /driver/toggle-availability مع {'isAvailable': isAvailable}.
  /// تُرجع true عند النجاح، false عند الفشل.
  Future<bool> toggleAvailability(bool isAvailable) async {
    if (!backendEnabled) return true;
    await _ensureTokenLoaded();

    logFine('ApiService', '[toggleAvailability] → isAvailable: $isAvailable');
    logFine('ApiService', '[toggleAvailability] → token present: $hasToken');

    try {
      await _dio.post(
        '/driver/toggle-availability',
        data: {'isAvailable': isAvailable},
      );
      logFine('ApiService', '[toggleAvailability] ✅ success');
      return true;
    } on DioException catch (e) {
      logWarning('ApiService', '[toggleAvailability] DioException: $e');
      return false;
    } catch (e) {
      logError('ApiService', 'AVAILABILITY TOGGLE ERROR: $e', e);
      return false;
    }
  }

  /// Get earnings summary for the given [period] (daily | weekly | monthly).
  Future<Map<String, dynamic>> getEarnings({required String period}) async {
    if (!backendEnabled) return <String, dynamic>{};
    final response = await _dio.get(
      '/driver/earnings',
      queryParameters: {'period': period},
    );
    return response.data as Map<String, dynamic>;
  }

  /// جلب سجل رحلات الكابتن من الباك إند.
  ///
  /// يُرسل طلب GET إلى `/rides/history` مع توكن الكابتن في الـ Header.
  /// تُرجع [List<RideModel>]؛ وفي حالة الفشل تُرجع قائمة فارغة لتجنب كسر التطبيق.
  Future<List<RideModel>> getRideHistory() async {
    if (!backendEnabled) return <RideModel>[];
    await _ensureTokenLoaded();
    try {
      final response = await _dio.get('/rides/history');
      final body = response.data as Map<String, dynamic>;
      final List<dynamic>? raw =
          body['rides'] as List<dynamic>? ?? body['data'] as List<dynamic>?;
      if (raw == null) return <RideModel>[];
      return raw
          .whereType<Map<String, dynamic>>()
          .map((json) => RideModel.fromJson(json))
          .toList();
    } catch (e) {
      logError('ApiService', 'getRideHistory error: $e', e);
      return <RideModel>[];
    }
  }

  // ── User Endpoints ───────────────────────────────────

  /// Get user profile
  Future<Map<String, dynamic>> getProfile() async {
    if (!backendEnabled) return <String, dynamic>{};
    final response = await _dio.get('/user/profile');
    return response.data as Map<String, dynamic>;
  }

  /// Update user profile
  Future<Map<String, dynamic>> updateProfile({
    String? firstName,
    String? lastName,
    String? avatarUrl,
  }) async {
    if (!backendEnabled) return <String, dynamic>{'success': true};
    final response = await _dio.put(
      '/user/profile/update',
      data: {
        if (firstName != null) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Get the driver's ratings summary + list of individual ratings.
  ///
  /// Uses `/user/ratings/{userId}` (the only ratings endpoint available on the
  /// deployed backend). Requires the JWT to have been loaded first so the
  /// `userId` claim can be extracted from the token payload.
  Future<Map<String, dynamic>> getDriverRatings() async {
    if (!backendEnabled) return <String, dynamic>{};
    await _ensureTokenLoaded();
    final uid = userId;
    if (uid == null) {
      logWarning(
        'ApiService',
        'getDriverRatings — userId is null, token may be missing',
      );
      return <String, dynamic>{};
    }
    final response = await _dio.get('/user/ratings/$uid');
    return response.data as Map<String, dynamic>;
  }

  /// Send a support chat message (sender = USER) and return the saved message.
  Future<Map<String, dynamic>> sendSupportMessage(String text) async {
    if (!backendEnabled) return <String, dynamic>{};
    final response = await _dio.post('/support/messages', data: {'text': text});
    return response.data as Map<String, dynamic>;
  }

  /// Get the current user's full support conversation.
  Future<Map<String, dynamic>> getSupportMessages() async {
    if (!backendEnabled) return <String, dynamic>{};
    final response = await _dio.get('/support/messages');
    return response.data as Map<String, dynamic>;
  }

  /// Rate a user
  Future<Map<String, dynamic>> rateUser({
    required String rideId,
    required String toUserId,
    required int rating,
    String? comment,
  }) async {
    if (!backendEnabled) return <String, dynamic>{'success': true};
    final response = await _dio.post(
      '/rate',
      data: {
        'rideId': rideId,
        'toUserId': toUserId,
        'rating': rating,
        if (comment != null) 'comment': comment,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Resubmit the captain's application after rejection.
  ///
  /// Sends updated document URLs to the backend so the admin can re-review
  /// the application. The backend updates the driver's documents and sets
  /// [verificationStatus] back to PENDING.
  ///
  /// Returns the backend response map on success.
  /// Throws [ApiException] on failure.
  Future<Map<String, dynamic>> resubmitApplication({
    String? idCardUrl,
    String? idCardBackUrl,
    String? licenseUrl,
    String? licenseBackUrl,
    String? vehicleLicenseFrontUrl,
    String? vehicleLicenseBackUrl,
    String? criminalRecordUrl,
    String? drugTestUrl,
    String? carPhotoUrl,
    String? faceUrl,
  }) async {
    if (!backendEnabled) return <String, dynamic>{'success': true};

    final Map<String, dynamic> payload = {
      if (idCardUrl != null && idCardUrl.isNotEmpty) 'idCardUrl': idCardUrl,
      if (idCardBackUrl != null && idCardBackUrl.isNotEmpty)
        'idCardBackUrl': idCardBackUrl,
      if (licenseUrl != null && licenseUrl.isNotEmpty) 'licenseUrl': licenseUrl,
      if (licenseBackUrl != null && licenseBackUrl.isNotEmpty)
        'licenseBackUrl': licenseBackUrl,
      if (vehicleLicenseFrontUrl != null && vehicleLicenseFrontUrl.isNotEmpty)
        'vehicleLicenseFrontUrl': vehicleLicenseFrontUrl,
      if (vehicleLicenseBackUrl != null && vehicleLicenseBackUrl.isNotEmpty)
        'vehicleLicenseBackUrl': vehicleLicenseBackUrl,
      if (criminalRecordUrl != null && criminalRecordUrl.isNotEmpty)
        'criminalRecordUrl': criminalRecordUrl,
      if (drugTestUrl != null && drugTestUrl.isNotEmpty)
        'drugTestUrl': drugTestUrl,
      if (carPhotoUrl != null && carPhotoUrl.isNotEmpty)
        'carPhotoUrl': carPhotoUrl,
      if (faceUrl != null && faceUrl.isNotEmpty) 'faceUrl': faceUrl,
    };

    try {
      final response = await _dio.post(
        '/auth/resubmit-application',
        data: payload,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException(
        message:
            _extractBackendMessage(e) ??
            'فشل إعادة تقديم الطلب (${e.response?.statusCode})',
      );
    }
  }
}
