import 'package:waslny_captain/core/models/wallet_models.dart';
import 'package:waslny_captain/core/services/api_service.dart';

/// Repository that manages wallet data exclusively via the Backend API.
///
/// All data comes from the Node.js/Express backend (PostgreSQL).
/// Firebase/Firestore is NOT used — Firebase is only for Authentication.
///
/// Methods that modify data (withdraw, payment methods) delegate directly
/// to [ApiService] and throw [ApiException] on failure so the UI can
/// surface meaningful error messages.
class WalletRepository {
  WalletRepository._();
  static final WalletRepository instance = WalletRepository._();

  final ApiService _api = ApiService.instance;

  // ──────────────────────────────────────────────────────
  // Wallet / Balance
  // ──────────────────────────────────────────────────────

  /// Fetch the driver's wallet data (balance, pending withdraw) once.
  /// Throws [ApiException] on failure.
  Future<WalletData> fetchWallet(String uid) async {
    final result = await _api.getWalletBalance();
    return WalletData(
      balance: (result['balance'] as num?)?.toDouble() ?? 0,
      pendingWithdraw: (result['pendingWithdraw'] as num?)?.toDouble() ?? 0,
      totalEarned: (result['totalEarned'] as num?)?.toDouble() ?? 0,
      totalWithdrawn: (result['totalWithdrawn'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Convenience alias for a one-shot wallet fetch.
  Future<WalletData> fetchWalletData(String uid) => fetchWallet(uid);

  /// Re-fetches wallet data from the backend.
  /// Useful after completing a top-up or ride to get the latest balance.
  Future<WalletData> refreshWallet(String uid) => fetchWallet(uid);

  // ──────────────────────────────────────────────────────
  // Transactions
  // ──────────────────────────────────────────────────────

  /// Fetch the most recent transactions from the backend API.
  /// Throws [ApiException] on failure.
  Future<List<WalletTransaction>> fetchTransactions(
    String uid, {
    int limit = 50,
  }) async {
    final result = await _api.getWalletTransactions();
    final list = result['transactions'] as List<dynamic>? ?? [];
    return list.map((tx) {
      final map = tx as Map<String, dynamic>;
      return WalletTransaction(
        id: map['id'] as String? ?? '',
        type: map['type'] as String? ?? 'earning',
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        description: map['description'] as String? ?? '',
        status: map['status'] as String? ?? 'completed',
        createdAt: map['createdAt'] != null
            ? _parseDate(map['createdAt'])
            : DateTime.now(),
      );
    }).toList();
  }

  // ──────────────────────────────────────────────────────
  // Withdraw Requests
  // ──────────────────────────────────────────────────────

  /// Fetch all withdraw requests for the driver, newest first.
  /// Throws [ApiException] on failure.
  Future<List<WithdrawRequest>> fetchWithdrawRequests(String uid) async {
    final result = await _api.getWithdrawals();
    final list = result['withdraws'] as List<dynamic>? ?? [];
    return list.map((wd) {
      final map = wd as Map<String, dynamic>;
      return WithdrawRequest(
        id: map['id'] as String? ?? '',
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        status: map['status'] as String? ?? 'pending',
        withdrawMethod: map['withdrawMethod'] as String? ?? 'BANK',
        bankAccount: map['bankAccount'] as String?,
        bankName: map['bankName'] as String?,
        accountHolder: map['accountHolder'] as String?,
        instapayId: map['instapayId'] as String?,
        createdAt: map['createdAt'] != null
            ? _parseDate(map['createdAt'])
            : DateTime.now(),
        updatedAt: map['updatedAt'] != null
            ? _parseDate(map['updatedAt'])
            : null,
      );
    }).toList();
  }

  /// Submit a new withdrawal request via the Backend API.
  /// يدعم التحويل البنكي (BANK) و InstaPay (INSTAPAY) و المحفظة (WALLET).
  Future<Map<String, dynamic>> submitWithdrawRequest(
    String uid, {
    required double amount,
    String withdrawMethod = 'BANK',
    String? bankName,
    String? bankAccount,
    String? accountHolder,
    String? instapayId,
    String? walletPhone,
  }) async {
    return _api.requestWithdraw(
      amount: amount,
      withdrawMethod: withdrawMethod,
      bankName: bankName,
      bankAccount: bankAccount,
      accountHolder: accountHolder,
      instapayId: instapayId,
      walletPhone: walletPhone,
    );
  }

  // ──────────────────────────────────────────────────────
  // Payment Methods
  // ──────────────────────────────────────────────────────

  /// Fetch saved payment methods from Backend API.
  /// Throws [ApiException] on failure.
  Future<List<PaymentMethod>> fetchPaymentMethods(String uid) async {
    final result = await _api.getPaymentMethods();
    final list = result['paymentMethods'] as List<dynamic>? ?? [];
    return list
        .cast<Map<String, dynamic>>()
        .map((json) => PaymentMethod.fromJson(json))
        .toList();
  }

  /// Adds a new payment method via the Backend API.
  Future<PaymentMethod> addPaymentMethod(
    String uid, {
    required String type,
    required String label,
    String? accountNumber,
    String? bankName,
    bool isDefault = false,
  }) async {
    final result = await _api.addPaymentMethod(
      type: type,
      label: label,
      accountNumber: accountNumber,
      bankName: bankName,
    );
    final json = result['paymentMethod'] as Map<String, dynamic>;
    return PaymentMethod.fromJson(json);
  }

  /// Deletes a saved payment method via the Backend API.
  Future<void> deletePaymentMethod(String uid, String id) async {
    await _api.deletePaymentMethod(id);
  }

  /// Sets a payment method as default via the Backend API.
  Future<void> setDefaultPaymentMethod(String uid, String id) async {
    await _api.setDefaultPaymentMethod(id);
  }

  // ──────────────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────────────

  /// Parse a date from various formats the backend might return.
  static DateTime _parseDate(dynamic value) {
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    if (value is num) {
      final ms = value.toInt();
      // أقل من 1e12 يُعتبر ثوانٍ، وإلا ملي ثوانٍ
      return DateTime.fromMillisecondsSinceEpoch(ms < 1e12 ? ms * 1000 : ms);
    }
    return DateTime.now();
  }
}
