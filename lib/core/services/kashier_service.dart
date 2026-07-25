import 'dart:async';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:kashier_flutter_sdk/kashier_flutter_sdk.dart';

import 'package:waslny_captain/core/services/auth_service.dart';
import 'package:waslny_captain/core/utils/logger.dart';

/// ----------------------------------------------------------------------------
/// Kashier Payment Service
/// ----------------------------------------------------------------------------
///
/// Integrates Kashier (https://kashier.io) Egyptian payment gateway into the
/// Waslny Captain app.
///
/// Two session‑creation modes are supported:
///
///   **Mode A – Direct API (testing/development)**
///   The app calls the Kashier API directly.  This is the simplest approach
///   but exposes your API secret key in the mobile binary.
///
///   **Mode B – Firebase Cloud Function (production)**
///   The app calls a Firebase `Callable` function which securely creates the
///   payment session on the server.  The secret key never leaves your backend.
///
/// Environment setup:
///   1. Create a Kashier merchant account at https://dashboard.kashier.io
///   2. Copy your **API Key** and **Secret Key** from the Integrations page
///   3. Copy your **Merchant ID** from the Account page
///   4. Paste them into the constants below (test values first)
///   5. Set `useCloudFunction(true)` when your Cloud Function is deployed.
///
/// The companion Cloud Function is at `functions/index.js`.
/// ----------------------------------------------------------------------------
class KashierService {
  KashierService._();
  static final KashierService instance = KashierService._();

  // ══════════════════════════════════════════════════════════════════════════
  // CONFIGURATION
  // ══════════════════════════════════════════════════════════════════════════

  bool _useCloudFunction = false;
  bool _isLiveMode = false;
  String _apiKey = '';
  String _secretKey = '';
  String _merchantId = '';

  /// Base URL for Kashier Payment Sessions API.
  String get _baseUrl => _isLiveMode
      ? 'https://api.kashier.io/v3'
      : 'https://test-api.kashier.io/v3';

  // ══════════════════════════════════════════════════════════════════════════
  // CONFIGURATION METHODS
  // ══════════════════════════════════════════════════════════════════════════

  /// Configure the service.  Call once during app startup.
  void configure({
    bool useCloudFunction = false,
    bool isLiveMode = false,
    String? apiKey,
    String? secretKey,
    String? merchantId,
  }) {
    _useCloudFunction = useCloudFunction;
    _isLiveMode = isLiveMode;
    if (apiKey != null) _apiKey = apiKey;
    if (secretKey != null) _secretKey = secretKey;
    if (merchantId != null) _merchantId = merchantId;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ══════════════════════════════════════════════════════════════════════════

  /// Start a **top‑up** (add balance) payment flow.
  ///
  /// 1. Creates a Kashier payment session.
  /// 2. Launches the native Kashier payment sheet.
  /// 3. On success, updates the wallet balance in Firestore.
  ///
  /// Returns `true` if the payment succeeded, `false` otherwise.
  /// Start a **top‑up** (add balance) payment flow.
  ///
  /// Returns `null` on success, or an Arabic error message describing the
  /// failure so the UI can show the real reason instead of a generic text.
  Future<String?> topUpWallet({
    required double amount,
    String currency = 'EGP',
  }) async {
    if (kIsWeb) {
      _debugLog('Kashier is not available on Web');
      return 'Kashier غير متاح على متصفح الويب';
    }

    final uid = AuthService.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      _debugLog('User not authenticated');
      return 'يجب تسجيل الدخول أولاً';
    }

    try {
      // ── 1. Create a payment session ──────────────────────────────────────
      final (sessionId, sessionError) = await _createPaymentSession(
        amount: amount,
        currency: currency,
        uid: uid,
      );

      if (sessionId == null) {
        _debugLog('Failed to create Kashier session: $sessionError');
        return sessionError ?? 'فشل إنشاء جلسة الدفع';
      }

      _debugLog('Session created: $sessionId');

      // ── 2. Launch the Kashier payment sheet ──────────────────────────────
      final completer = Completer<String?>();

      KashierSDK.startPayment(
        sessionId: sessionId,
        onSuccess: (KashierPaymentResult result) async {
          _debugLog('Payment success – transaction: ${result.transactionId}');
          final err = await _onPaymentSuccess(
            uid: uid,
            amount: amount,
            currency: currency,
            sessionId: sessionId,
          );
          completer.complete(err);
        },
        onPending: (KashierPaymentPending pending) {
          _debugLog('Payment pending – order: ${pending.orderId}');
          completer.complete(null);
        },
        onFailure: (KashierPaymentError error) {
          if (error.code == KashierErrorCode.userCancelled) {
            _debugLog('User cancelled the payment');
            completer.complete('تم إلغاء عملية الدفع');
          } else {
            _debugLog(
              'Payment failed – code: ${error.code}, message: ${error.message}',
            );
            final msg = error.message;
            completer.complete(msg.isNotEmpty ? msg : 'فشلت عملية الدفع');
          }
        },
      );

      return completer.future;
    } catch (e) {
      _debugLog('topUpWallet error: $e');
      return 'حدث خطأ غير متوقع أثناء الدفع';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INTERNAL – Session creation
  // ══════════════════════════════════════════════════════════════════════════

  /// Creates a Kashier payment session.
  ///
  /// Delegates to a Cloud Function or calls the Kashier API directly
  /// depending on [_useCloudFunction].
  Future<(String? sessionId, String? error)> _createPaymentSession({
    required double amount,
    required String currency,
    required String uid,
  }) async {
    if (_useCloudFunction) {
      return _createSessionViaCloudFunction(amount: amount, currency: currency);
    }
    final id = await _createSessionDirectApi(
      amount: amount,
      currency: currency,
      uid: uid,
    );
    return (
      id,
      id == null ? 'فشل إنشاء الجلسة مباشرة (تحقق من المفاتيح)' : null,
    );
  }

  /// Create session via Firebase Cloud Function.
  ///
  /// To use this, add `cloud_functions: ^5.0.0` to pubspec.yaml and uncomment
  /// the code below.
  /// Create session via Firebase Cloud Function.
  ///
  /// Returns a record: (sessionId, error). `error` is non-null when the
  /// session could not be created, carrying the server's Arabic message.
  Future<(String? sessionId, String? error)> _createSessionViaCloudFunction({
    required double amount,
    required String currency,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'createKashierSession',
      );
      final result = await callable.call<Map<String, dynamic>>({
        'amount': amount,
        'currency': currency,
      });
      final sessionId = result.data['sessionId'] as String?;
      if (sessionId == null) {
        return (null, 'لم يُرجع الخادم معرّف جلسة الدفع');
      }
      return (sessionId, null);
    } on FirebaseFunctionsException catch (e) {
      _debugLog('Cloud Function error: ${e.code} - ${e.message}');
      return (null, e.message ?? 'خطأ من خادم الدفع');
    } catch (e) {
      _debugLog('Cloud Function error: $e');
      return (null, e.toString());
    }
  }

  /// Create session by calling the Kashier API directly.
  ///
  /// ⚠️  For development/testing only.  The API secret key is embedded in the
  /// app binary, which is not secure for production.
  Future<String?> _createSessionDirectApi({
    required double amount,
    required String currency,
    required String uid,
  }) async {
    final orderId =
        'waslny_${uid.substring(0, 8)}_${DateTime.now().millisecondsSinceEpoch}';

    final body = {
      'amount': amount.toStringAsFixed(2),
      'currency': currency,
      'order': orderId,
      'merchantId': _merchantId,
      'mode': _isLiveMode ? 'live' : 'test',
      'type': 'one-time',
      'paymentType': 'credit',
      'display': 'ar',
      'allowedMethods': 'card,wallet',
      'expireAt': DateTime.now()
          .add(const Duration(hours: 1))
          .toUtc()
          .toIso8601String(),
      'maxFailureAttempts': 3,
      'metaData': jsonEncode({
        'driverUid': uid,
        'source': 'waslny_captain_topup',
      }),
    };

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/payment/sessions'),
        headers: {
          'Authorization': _secretKey,
          'api-key': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['_id'] as String?;
      } else {
        _debugLog(
          'Session creation failed: ${response.statusCode} ${response.body}',
        );
        return null;
      }
    } catch (e) {
      _debugLog('HTTP error creating session: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INTERNAL – Success handling
  // ══════════════════════════════════════════════════════════════════════════

  /// Called when the Kashier SDK reports a successful payment.
  ///
  /// Delegates the **authoritative** wallet update to the server-side
  /// `confirmKashierTopUp` Cloud Function, which performs an atomic,
  /// idempotent Firestore transaction (balance + deposit transaction). This
  /// keeps the secret/server logic server-side and prevents the client from
  /// tampering with the balance. The `kashierWebhook` is an extra Kashier-
  /// verified safety net and is also idempotent, so there is never a double
  /// credit.
  ///
  /// Returns `null` on success, or an Arabic error message on failure.
  Future<String?> _onPaymentSuccess({
    required String uid,
    required double amount,
    required String currency,
    required String sessionId,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'confirmKashierTopUp',
      );
      await callable.call<Map<String, dynamic>>({
        'sessionId': sessionId,
        'amount': amount,
      });
      _debugLog(
        'Server confirmed top-up: +$amount $currency (session $sessionId)',
      );
      return null;
    } on FirebaseFunctionsException catch (e) {
      _debugLog('confirmKashierTopUp error: ${e.code} - ${e.message}');
      return e.message ?? 'تعذّر تأكيد الدفع من الخادم';
    } catch (e) {
      _debugLog('confirmKashierTopUp error: $e');
      return 'تعذّر تأكيد الدفع من الخادم';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  void _debugLog(String message) {
    logInfo('KashierService', message);
  }
}
