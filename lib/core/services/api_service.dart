// ignore_for_file: use_null_aware_elements

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:waslny_captain/core/models/ride_model.dart';

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
      debugPrint('saveToken persist failed: $e');
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
      debugPrint('loadToken failed: $e');
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
      debugPrint('clearToken persist failed: $e');
    }
  }

  bool get hasToken => _token != null && _token!.isNotEmpty;

  /// Ensures a JWT is present in memory before sending an authenticated
  /// request. If the in-memory token is missing (e.g. after a cold start),
  /// it attempts to restore it from local storage to avoid 401 errors.
  Future<void> _ensureTokenLoaded() async {
    if (hasToken) return;
    await loadToken();
  }

  // ── HTTP Helpers ─────────────────────────────────────

  Map<String, String> _headers({bool auth = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth && _token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    throw ApiException(
      message: body['error'] as String? ?? 'خطأ في الاتصال بالسيرفر',
      statusCode: response.statusCode,
    );
  }

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
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/firebase'),
      headers: _headers(auth: false),
      body: jsonEncode({'idToken': firebaseIdToken}),
    );
    final result = await _handleResponse(response);
    if (result['token'] != null) {
      saveToken(result['token'] as String);
    }
    return result;
  }

  /// Send OTP to phone number
  Future<Map<String, dynamic>> sendOtp(
    String phoneNumber, {
    String? firstName,
    String? lastName,
  }) async {
    if (!backendEnabled) return <String, dynamic>{'success': true};
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/send-otp'),
      headers: _headers(auth: false),
      body: jsonEncode({
        'phoneNumber': phoneNumber,
        if (firstName != null) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
      }),
    );
    return _handleResponse(response);
  }

  /// Verify OTP and get JWT token
  Future<Map<String, dynamic>> verifyOtp(String phoneNumber, String otp) async {
    if (!backendEnabled) return <String, dynamic>{'success': true};
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/verify-otp'),
      headers: _headers(auth: false),
      body: jsonEncode({'phoneNumber': phoneNumber, 'otp': otp}),
    );
    final result = await _handleResponse(response);
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
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register-fcm-token'),
        headers: _headers(),
        body: jsonEncode({'fcmToken': token}),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('✅ FCM token registered with backend');
        return true;
      }
      debugPrint(
        'updateFcmTokenToServer failed: ${response.statusCode} ${response.body}',
      );
      return false;
    } catch (e) {
      debugPrint('updateFcmTokenToServer error: $e');
      return false;
    }
  }

  /// Register as a driver
  Future<Map<String, dynamic>> registerDriver({
    required String carModel,
    required String carPlateNumber,
    required String carColor,
    required String vehicleType,
    required String carPhotoUrl,
  }) async {
    if (!backendEnabled) return <String, dynamic>{'success': true};
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/register-driver'),
      headers: _headers(),
      body: jsonEncode({
        // Explicitly register as a DRIVER so the backend does not default
        // the account to "RIDER" (which would cause 403 on driver endpoints).
        'role': 'DRIVER',
        'carModel': carModel,
        'carPlateNumber': carPlateNumber,
        'carColor': carColor,
        'vehicleType': vehicleType,
        'carPhotoUrl': carPhotoUrl,
      }),
    );
    final result = await _handleResponse(response);
    if (result['token'] != null) {
      saveToken(result['token'] as String);
    }
    return result;
  }

  // ── Wallet Endpoints ─────────────────────────────────

  /// Get wallet balance
  Future<Map<String, dynamic>> getWalletBalance() async {
    if (!backendEnabled) return <String, dynamic>{};
    await _ensureTokenLoaded();
    final response = await http.get(
      Uri.parse('$_baseUrl/wallet/balance'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  /// Get wallet transactions
  Future<Map<String, dynamic>> getWalletTransactions() async {
    if (!backendEnabled) return <String, dynamic>{};
    await _ensureTokenLoaded();
    final response = await http.get(
      Uri.parse('$_baseUrl/wallet/transactions'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  /// Request a withdrawal
  Future<Map<String, dynamic>> requestWithdraw({
    required double amount,
    required String bankName,
    required String bankAccount,
    required String accountHolder,
  }) async {
    if (!backendEnabled) return <String, dynamic>{'success': true};
    final response = await http.post(
      Uri.parse('$_baseUrl/wallet/withdraw'),
      headers: _headers(),
      body: jsonEncode({
        'amount': amount,
        'bankName': bankName,
        'bankAccount': bankAccount,
        'accountHolder': accountHolder,
      }),
    );
    return _handleResponse(response);
  }

  /// Get withdrawal history
  Future<Map<String, dynamic>> getWithdrawals() async {
    if (!backendEnabled) return <String, dynamic>{};
    await _ensureTokenLoaded();
    final response = await http.get(
      Uri.parse('$_baseUrl/wallet/withdraws'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  /// Top up the wallet via the Kashier payment gateway.
  ///
  /// The backend creates the Kashier session and returns either a
  /// `paymentUrl` to redirect the captain to, or the updated `balance`
  /// when the top-up is applied directly.
  Future<Map<String, dynamic>> topUpWallet({required double amount}) async {
    if (!backendEnabled) return <String, dynamic>{};
    final response = await http.post(
      Uri.parse('$_baseUrl/wallet/top-up'),
      headers: _headers(),
      body: jsonEncode({'amount': amount, 'paymentMethod': 'card'}),
    );
    return _handleResponse(response);
  }

  /// Initiate a Kashier payment session for wallet top-up.
  ///
  /// Creates a new payment session on the backend and returns the `sessionId`
  /// and `paymentUrl` for use in the in-app WebView checkout.
  Future<Map<String, dynamic>> initiatePayment({
    required double amount,
    String paymentMethod = 'card',
  }) async {
    if (!backendEnabled) return <String, dynamic>{};
    await _ensureTokenLoaded();
    final response = await http.post(
      Uri.parse('$_baseUrl/wallet/initiate-payment'),
      headers: _headers(),
      body: jsonEncode({'amount': amount, 'paymentMethod': paymentMethod}),
    );
    return _handleResponse(response);
  }

  // ── Driver Endpoints ─────────────────────────────────

  /// Update driver location
  Future<Map<String, dynamic>> updateLocation(double lat, double lng) async {
    if (!backendEnabled) return <String, dynamic>{'success': true};
    final response = await http.put(
      Uri.parse('$_baseUrl/driver/location'),
      headers: _headers(),
      body: jsonEncode({'lat': lat, 'lng': lng}),
    );
    return _handleResponse(response);
  }

  /// Get available rides nearby
  Future<Map<String, dynamic>> getAvailableRides() async {
    if (!backendEnabled) return <String, dynamic>{};
    final response = await http.get(
      Uri.parse('$_baseUrl/driver/available-rides'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  /// قبول طلب رحلة (POST). تُرجع true عند النجاح، false عند الفشل.
  Future<bool> acceptRide(String rideId) async {
    if (!backendEnabled) return true;
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/driver/accept-ride/$rideId'),
        headers: _headers(),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
      debugPrint('acceptRide failed: ${response.statusCode} ${response.body}');
      return false;
    } catch (e) {
      debugPrint('acceptRide error: $e');
      return false;
    }
  }

  /// بدء الرحلة (PUT). تُرجع true عند النجاح، false عند الفشل.
  Future<bool> startRide(String rideId) async {
    if (!backendEnabled) return true;
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/driver/ride/start/$rideId'),
        headers: _headers(),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
      debugPrint('startRide failed: ${response.statusCode} ${response.body}');
      return false;
    } catch (e) {
      debugPrint('startRide error: $e');
      return false;
    }
  }

  /// إنهاء الرحلة (PUT). تُرجع true عند النجاح، false عند الفشل.
  Future<bool> completeRide(String rideId) async {
    if (!backendEnabled) return true;
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/driver/ride/complete/$rideId'),
        headers: _headers(),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
      debugPrint(
        'completeRide failed: ${response.statusCode} ${response.body}',
      );
      return false;
    } catch (e) {
      debugPrint('completeRide error: $e');
      return false;
    }
  }

  /// تأكيد وصول الكابتن لنقطة الالتقاط (PUT). تُرجع true عند النجاح، false عند الفشل.
  Future<bool> arriveRide(String rideId) async {
    if (!backendEnabled) return true;
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/driver/ride/arrive/$rideId'),
        headers: _headers(),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
      debugPrint('arriveRide failed: ${response.statusCode} ${response.body}');
      return false;
    } catch (e) {
      debugPrint('arriveRide error: $e');
      return false;
    }
  }

  /// تبديل حالة توافر الكابتن (Online/Offline) في الباك إند.
  /// يُرسل POST إلى /driver/toggle-availability مع {'isAvailable': isAvailable}.
  /// تُرجع true عند النجاح، false عند الفشل.
  Future<bool> toggleAvailability(bool isAvailable) async {
    if (!backendEnabled) return true;
    // Ensure the JWT is present in memory (restores from local storage on
    // cold start) so the Authorization header is always sent. Without this,
    // the request can go out unauthenticated and the backend returns 401,
    // which surfaces as "تعذر مزامنة حالة التوافر مع السيرفر".
    await _ensureTokenLoaded();

    final url = '$_baseUrl/driver/toggle-availability';
    final headers = _headers();
    final tokenPresent = headers['Authorization'] != null;
    debugPrint('[toggleAvailability] → POST $url');
    debugPrint('[toggleAvailability] → isAvailable: $isAvailable');
    debugPrint('[toggleAvailability] → token present: $tokenPresent');
    debugPrint(
      '[toggleAvailability] → Authorization header: '
      '${tokenPresent ? headers['Authorization']!.substring(0, 20) + '…' : 'NULL'}',
    );

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode({'isAvailable': isAvailable}),
      );
      debugPrint('[toggleAvailability] ← status: ${response.statusCode}');
      debugPrint('[toggleAvailability] ← body: ${response.body}');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
      debugPrint(
        'toggleAvailability failed: ${response.statusCode} ${response.body}',
      );
      return false;
    } catch (e) {
      debugPrint('AVAILABILITY TOGGLE ERROR: $e');
      return false;
    }
  }

  /// Get earnings summary for the given [period] (daily | weekly | monthly).
  Future<Map<String, dynamic>> getEarnings({required String period}) async {
    if (!backendEnabled) return <String, dynamic>{};
    final response = await http.get(
      Uri.parse('$_baseUrl/driver/earnings?period=$period'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  /// جلب سجل رحلات الكابتن من الباك إند.
  ///
  /// يُرسل طلب GET إلى `/driver/rides/history` مع توكن الكابتن في الـ Header.
  /// تُرجع [List<RideModel>]؛ وفي حالة الفشل تُرجع قائمة فارغة لتجنب كسر التطبيق.
  Future<List<RideModel>> getRideHistory() async {
    if (!backendEnabled) return <RideModel>[];
    await _ensureTokenLoaded();
    try {
      // Correct backend route (verified: /driver/rides/history → 404,
      // /rides/history → 401, i.e. exists and requires auth).
      final response = await http.get(
        Uri.parse('$_baseUrl/rides/history'),
        headers: _headers(),
      );
      final body = await _handleResponse(response);
      final List<dynamic>? raw =
          body['rides'] as List<dynamic>? ?? body['data'] as List<dynamic>?;
      if (raw == null) return <RideModel>[];
      return raw
          .whereType<Map<String, dynamic>>()
          .map((json) => RideModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('getRideHistory error: $e');
      return <RideModel>[];
    }
  }

  // ── User Endpoints ───────────────────────────────────

  /// Get user profile
  Future<Map<String, dynamic>> getProfile() async {
    if (!backendEnabled) return <String, dynamic>{};
    final response = await http.get(
      Uri.parse('$_baseUrl/user/profile'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  /// Update user profile
  Future<Map<String, dynamic>> updateProfile({
    String? firstName,
    String? lastName,
    String? avatarUrl,
  }) async {
    if (!backendEnabled) return <String, dynamic>{'success': true};
    final response = await http.put(
      Uri.parse('$_baseUrl/user/profile/update'),
      headers: _headers(),
      body: jsonEncode({
        if (firstName != null) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      }),
    );
    return _handleResponse(response);
  }

  /// Get the driver's ratings summary + list of individual ratings.
  Future<Map<String, dynamic>> getDriverRatings() async {
    if (!backendEnabled) return <String, dynamic>{};
    final response = await http.get(
      Uri.parse('$_baseUrl/driver/ratings'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  /// Send a support chat message (sender = USER) and return the saved message.
  Future<Map<String, dynamic>> sendSupportMessage(String text) async {
    if (!backendEnabled) return <String, dynamic>{};
    final response = await http.post(
      Uri.parse('$_baseUrl/support/messages'),
      headers: _headers(),
      body: jsonEncode({'text': text}),
    );
    return _handleResponse(response);
  }

  /// Get the current user's full support conversation.
  Future<Map<String, dynamic>> getSupportMessages() async {
    if (!backendEnabled) return <String, dynamic>{};
    final response = await http.get(
      Uri.parse('$_baseUrl/support/messages'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  /// Rate a user
  Future<Map<String, dynamic>> rateUser({
    required String rideId,
    required String toUserId,
    required int rating,
    String? comment,
  }) async {
    if (!backendEnabled) return <String, dynamic>{'success': true};
    final response = await http.post(
      Uri.parse('$_baseUrl/rate'),
      headers: _headers(),
      body: jsonEncode({
        'rideId': rideId,
        'toUserId': toUserId,
        'rating': rating,
        if (comment != null) 'comment': comment,
      }),
    );
    return _handleResponse(response);
  }
}

/// Exception thrown when an API request fails.
class ApiException implements Exception {
  final String message;
  final int statusCode;

  const ApiException({required this.message, required this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
