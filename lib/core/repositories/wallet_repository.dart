import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:waslny_captain/core/models/wallet_models.dart';
import 'package:waslny_captain/core/services/api_service.dart';

/// Repository that manages wallet data.
///
/// Uses the Backend API as the primary data source and Firestore
/// as a local cache / fallback for offline access.
///
/// Data is organised as:
/// - `wallets/{uid}`          → driver wallet document (balance, pendingWithdraw)
/// - `wallets/{uid}/transactions/{txId}` → individual transactions
/// - `wallets/{uid}/withdraws/{wdId}`    → withdrawal requests
///
/// When no data exists yet, [WalletRepository] returns realistic sample data
/// so the UI is never empty during development.
class WalletRepository {
  WalletRepository._();
  static final WalletRepository instance = WalletRepository._();

  final ApiService _api = ApiService.instance;

  // ──────────────────────────────────────────────────────
  // Firestore helpers (local cache)
  // ──────────────────────────────────────────────────────

  DocumentReference<Map<String, dynamic>> _walletRef(String uid) =>
      FirebaseFirestore.instance.collection('wallets').doc(uid);

  CollectionReference<Map<String, dynamic>> _txRef(String uid) =>
      _walletRef(uid).collection('transactions');

  CollectionReference<Map<String, dynamic>> _withdrawRef(String uid) =>
      _walletRef(uid).collection('withdraws');

  CollectionReference<Map<String, dynamic>> _pmRef(String uid) =>
      _walletRef(uid).collection('paymentMethods');

  // ──────────────────────────────────────────────────────
  // Public API – Wallet / Balance
  // ──────────────────────────────────────────────────────

  /// Fetch the driver's wallet data (balance, pending withdraw).
  /// Priority: Backend API > Firestore > Sample data.
  Future<WalletData> fetchWallet(String uid) async {
    try {
      // Try backend API first
      final result = await _api.getWalletBalance();
      if (result['balance'] != null) {
        final wallet = WalletData(
          balance: (result['balance'] as num).toDouble(),
          pendingWithdraw: (result['pendingWithdraw'] as num?)?.toDouble() ?? 0,
          totalEarned: (result['totalEarned'] as num?)?.toDouble() ?? 0,
          totalWithdrawn: (result['totalWithdrawn'] as num?)?.toDouble() ?? 0,
        );
        // Cache to Firestore
        await _walletRef(uid).set(wallet.toMap(), SetOptions(merge: true));
        return wallet;
      }
    } catch (_) {
      // Fallback to Firestore
    }

    try {
      final doc = await _walletRef(uid).get();
      if (!doc.exists || doc.data() == null) return _sampleWalletData();
      return WalletData.fromMap(doc.data()!);
    } catch (_) {
      return _sampleWalletData();
    }
  }

  /// Stream the driver's wallet data in real time.
  /// Uses Firestore for real-time updates (falls back to polling).
  Stream<WalletData> streamWallet(String uid) {
    return _walletRef(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return _sampleWalletData();
      return WalletData.fromMap(doc.data()!);
    });
  }

  /// Update the wallet balance (e.g. after completing a ride).
  Future<void> updateBalance(String uid, double newBalance) async {
    await _walletRef(uid).set({
      'balance': newBalance,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Refresh wallet data from the backend API and update local cache.
  Future<WalletData> refreshWallet(String uid) async {
    return fetchWallet(uid);
  }

  // ──────────────────────────────────────────────────────
  // Public API – Transactions
  // ──────────────────────────────────────────────────────

  /// Fetch the most recent transactions.
  /// Priority: Backend API > Firestore > Sample data.
  Future<List<WalletTransaction>> fetchTransactions(
    String uid, {
    int limit = 50,
  }) async {
    try {
      final result = await _api.getWalletTransactions();
      if (result['transactions'] != null) {
        final list = result['transactions'] as List;
        return list.map((tx) {
          return WalletTransaction(
            id: tx['id'] as String? ?? '',
            type: tx['type'] as String? ?? 'earning',
            amount: (tx['amount'] as num?)?.toDouble() ?? 0,
            description: tx['description'] as String? ?? '',
            status: tx['status'] as String? ?? 'completed',
            createdAt: tx['createdAt'] != null
                ? DateTime.parse(tx['createdAt'] as String)
                : DateTime.now(),
          );
        }).toList();
      }
    } catch (_) {
      // Fallback to Firestore
    }

    try {
      final snap = await _txRef(
        uid,
      ).orderBy('createdAt', descending: true).limit(limit).get();
      if (snap.docs.isEmpty) return _sampleTransactions();
      return snap.docs
          .map((d) => WalletTransaction.fromMap(d.id, d.data()))
          .toList();
    } catch (_) {
      return _sampleTransactions();
    }
  }

  /// Add a transaction entry (e.g. when a ride is completed or a withdraw is
  /// processed).
  Future<void> addTransaction(String uid, WalletTransaction tx) async {
    await _txRef(uid).add(tx.toMap());
  }

  // ──────────────────────────────────────────────────────
  // Public API – Withdraw Requests
  // ──────────────────────────────────────────────────────

  /// Fetch all withdraw requests for the driver, newest first.
  /// Priority: Backend API > Firestore > Sample data.
  Future<List<WithdrawRequest>> fetchWithdrawRequests(String uid) async {
    try {
      final result = await _api.getWithdrawals();
      if (result['withdraws'] != null) {
        final list = result['withdraws'] as List;
        return list.map((wd) {
          return WithdrawRequest(
            id: wd['id'] as String? ?? '',
            amount: (wd['amount'] as num?)?.toDouble() ?? 0,
            status: wd['status'] as String? ?? 'pending',
            bankAccount: wd['bankAccount'] as String?,
            bankName: wd['bankName'] as String?,
            accountHolder: wd['accountHolder'] as String?,
            createdAt: wd['createdAt'] != null
                ? DateTime.parse(wd['createdAt'] as String)
                : DateTime.now(),
            updatedAt: wd['updatedAt'] != null
                ? DateTime.parse(wd['updatedAt'] as String)
                : null,
          );
        }).toList();
      }
    } catch (_) {
      // Fallback to Firestore
    }

    try {
      final snap = await _withdrawRef(
        uid,
      ).orderBy('createdAt', descending: true).get();
      if (snap.docs.isEmpty) return _sampleWithdrawRequests();
      return snap.docs
          .map((d) => WithdrawRequest.fromMap(d.id, d.data()))
          .toList();
    } catch (_) {
      return _sampleWithdrawRequests();
    }
  }

  /// Submit a new withdrawal request.
  Future<void> submitWithdrawRequest(
    String uid, {
    required double amount,
    required String bankAccount,
    String? bankName,
    String? accountHolder,
  }) async {
    await _withdrawRef(uid).add({
      'amount': amount,
      'status': 'pending',
      'bankAccount': bankAccount,
      'bankName': bankName,
      'accountHolder': accountHolder,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ──────────────────────────────────────────────────────
  // Public API – Payment Methods
  // ──────────────────────────────────────────────────────

  /// Fetch saved payment methods.
  Future<List<PaymentMethod>> fetchPaymentMethods(String uid) async {
    try {
      final snap = await _pmRef(uid).get();
      if (snap.docs.isEmpty) return _samplePaymentMethods();
      return snap.docs
          .map((d) => PaymentMethod.fromMap(d.id, d.data()))
          .toList();
    } catch (_) {
      return _samplePaymentMethods();
    }
  }

  // ──────────────────────────────────────────────────────
  // Sample data
  // ──────────────────────────────────────────────────────

  WalletData _sampleWalletData() =>
      const WalletData(balance: 2450.00, pendingWithdraw: 350.00);

  List<WalletTransaction> _sampleTransactions() => [
    WalletTransaction(
      id: 's1',
      type: 'earning',
      amount: 85.50,
      description: 'رحلة من مدينة نصر إلى التجمع',
      status: 'completed',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    WalletTransaction(
      id: 's2',
      type: 'earning',
      amount: 62.00,
      description: 'رحلة من المهندسين إلى الدقي',
      status: 'completed',
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    WalletTransaction(
      id: 's3',
      type: 'earning',
      amount: 120.00,
      description: 'رحلة من الرحاب إلى المطار',
      status: 'completed',
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
    ),
    WalletTransaction(
      id: 's4',
      type: 'withdraw',
      amount: 500.00,
      description: 'سحب رصيد - البنك الأهلي',
      status: 'completed',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    WalletTransaction(
      id: 's5',
      type: 'earning',
      amount: 45.00,
      description: 'رحلة من الزمالك إلى جاردن سيتي',
      status: 'completed',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    WalletTransaction(
      id: 's6',
      type: 'withdraw',
      amount: 200.00,
      description: 'سحب رصيد - فودافون كاش',
      status: 'pending',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    WalletTransaction(
      id: 's7',
      type: 'earning',
      amount: 78.00,
      description: 'رحلة من المعادي إلى وسط البلد',
      status: 'completed',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  List<WithdrawRequest> _sampleWithdrawRequests() => [
    WithdrawRequest(
      id: 'w1',
      amount: 200.00,
      status: 'pending',
      bankAccount: '****1234',
      bankName: 'فودافون كاش',
      accountHolder: 'أحمد كابتن',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    WithdrawRequest(
      id: 'w2',
      amount: 500.00,
      status: 'completed',
      bankAccount: '****5678',
      bankName: 'البنك الأهلي',
      accountHolder: 'أحمد كابتن',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now().subtract(const Duration(days: 4)),
    ),
    WithdrawRequest(
      id: 'w3',
      amount: 350.00,
      status: 'approved',
      bankAccount: '****9012',
      bankName: 'إنستاباي',
      accountHolder: 'أحمد كابتن',
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      updatedAt: DateTime.now().subtract(const Duration(days: 6)),
    ),
    WithdrawRequest(
      id: 'w4',
      amount: 150.00,
      status: 'rejected',
      bankAccount: '****3456',
      bankName: 'البنك التجاري',
      accountHolder: 'أحمد كابتن',
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      updatedAt: DateTime.now().subtract(const Duration(days: 9)),
    ),
  ];

  List<PaymentMethod> _samplePaymentMethods() => [
    const PaymentMethod(
      id: 'pm1',
      type: 'bank',
      label: 'البنك الأهلي',
      accountNumber: '1234567890123456',
      bankName: 'البنك الأهلي المصري',
      isDefault: true,
    ),
    const PaymentMethod(
      id: 'pm2',
      type: 'vodafone_cash',
      label: 'فودافون كاش',
      accountNumber: '01001234567',
      isDefault: false,
    ),
    const PaymentMethod(
      id: 'pm3',
      type: 'instapay',
      label: 'إنستاباي',
      accountNumber: 'ahmed.captain@instapay',
      isDefault: false,
    ),
  ];
}
