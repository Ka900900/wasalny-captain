import 'dart:async';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:kashier_flutter_sdk/kashier_flutter_sdk.dart';

import 'package:waslny_captain/core/services/auth_service.dart';
import 'package:waslny_captain/core/repositories/wallet_repository.dart';
import 'package:waslny_captain/core/models/wallet_models.dart';

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
  Future<bool> topUpWallet({
    required double amount,
    String currency = 'EGP',
  }) async {
    if (kIsWeb) {
      _debugLog('Kashier is not available on Web');
      return false;
    }

    final uid = AuthService.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      _debugLog('User not authenticated');
      return false;
    }

    try {
      // ── 1. Create a payment session ──────────────────────────────────────
      final sessionId = await _createPaymentSession(
        amount: amount,
        currency: currency,
        uid: uid,
      );

      if (sessionId == null) {
        _debugLog('Failed to create Kashier session');
        return false;
      }

      _debugLog('Session created: $sessionId');

      // ── 2. Launch the Kashier payment sheet ──────────────────────────────
      final completer = Completer<bool>();

      KashierSDK.startPayment(
        sessionId: sessionId,
        onSuccess: (KashierPaymentResult result) async {
          _debugLog(
            'Payment success – transaction: ${result.transactionId}',
          );
          await _onPaymentSuccess(uid, amount, currency, result);
          completer.complete(true);
        },
        onPending: (KashierPaymentPending pending) {
          _debugLog('Payment pending – order: ${pending.orderId}');
          completer.complete(true);
        },
        onFailure: (KashierPaymentError error) {
          if (error.code == KashierErrorCode.userCancelled) {
            _debugLog('User cancelled the payment');
          } else {
            _debugLog(
              'Payment failed – code: ${error.code}, message: ${error.message}',
            );
          }
          completer.complete(false);
        },
      );

      return completer.future;
    } catch (e) {
      _debugLog('topUpWallet error: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INTERNAL – Session creation
  // ══════════════════════════════════════════════════════════════════════════

  /// Creates a Kashier payment session.
  ///
  /// Delegates to a Cloud Function or calls the Kashier API directly
  /// depending on [_useCloudFunction].
  Future<String?> _createPaymentSession({
    required double amount,
    required String currency,
    required String uid,
  }) async {
    if (_useCloudFunction) {
      return _createSessionViaCloudFunction(
        amount: amount,
        currency: currency,
      );
    }
    return _createSessionDirectApi(
      amount: amount,
      currency: currency,
      uid: uid,
    );
  }

  /// Create session via Firebase Cloud Function.
  ///
  /// To use this, add `cloud_functions: ^5.0.0` to pubspec.yaml and uncomment
  /// the code below.
  Future<String?> _createSessionViaCloudFunction({
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
      return result.data['sessionId'] as String?;
    } catch (e) {
      _debugLog('Cloud Function error: $e');
      return null;
    }
    //
    // ── Uncomment when cloud_functions is added ──────────────────────────
    // import 'package:cloud_functions/cloud_functions.dart';
    //
    // try {
    //   final result = await FirebaseFunctions.instance
    //       .httpsCallable('createKashierSession')
    //       .call({'amount': amount.toString(), 'currency': currency});
    //   return result.data['sessionId'] as String?;
    // } catch (e) {
    //   _debugLog('Cloud Function error: $e');
    //   return null;
    // }
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

  /// Called when a payment succeeds.  Updates wallet balance and records tx.
  Future<void> _onPaymentSuccess(
    String uid,
    double amount,
    String currency,
    KashierPaymentResult result,
  ) async {
    try {
      final repo = WalletRepository.instance;

      final wallet = await repo.fetchWallet(uid);
      final newBalance = wallet.balance + amount;

      await repo.updateBalance(uid, newBalance);

      await repo.addTransaction(
        uid,
        WalletTransaction(
          id: 'kashier_${result.transactionId}',
          type: 'payment',
          amount: amount,
          description: 'شحن المحفظة عبر Kashier',
          status: 'completed',
          createdAt: DateTime.now(),
        ),
      );

      _debugLog('Wallet topped up: +$amount $currency → $newBalance');
    } catch (e) {
      _debugLog('Error updating wallet after payment: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  void _debugLog(String message) {
    // ignore: avoid_print
    print('[KashierService] $message');
  }
}


