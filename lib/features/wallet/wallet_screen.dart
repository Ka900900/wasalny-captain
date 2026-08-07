import 'package:flutter/material.dart';

import 'package:waslny_captain/core/theme/app_theme.dart';
import 'package:waslny_captain/core/models/wallet_models.dart';
import 'package:waslny_captain/core/repositories/wallet_repository.dart';
import 'package:waslny_captain/core/network/api_exceptions.dart';
import 'package:waslny_captain/core/services/api_service.dart';
import 'package:waslny_captain/core/services/auth_service.dart';
import 'package:waslny_captain/features/earnings/earnings_screen.dart';
import 'package:waslny_captain/features/wallet/kashier_checkout_webview.dart';

/// Wallet tab sections.
enum WalletTab { transactions, withdraws, paymentMethods }

/// Full wallet screen with:
/// - Real-time balance card
/// - Quick action buttons
/// - Transactions / Withdraw Requests / Payment Methods tabs
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  WalletTab _currentTab = WalletTab.transactions;

  WalletData? _walletData;
  List<WalletTransaction> _transactions = [];
  List<WithdrawRequest> _withdrawRequests = [];
  List<PaymentMethod> _paymentMethods = [];

  bool _loadingWallet = true;
  bool _loadingTx = true;
  bool _loadingWd = true;
  bool _loadingPm = true;

  String _uid = '';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadAll() async {
    final uid = AuthService.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    _uid = uid;

    // Wallet data – single fetch from backend
    try {
      final data = await WalletRepository.instance.fetchWalletData(uid);
      if (mounted) {
        setState(() {
          _walletData = data;
          _loadingWallet = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingWallet = false);
      }
    }

    // One-shot fetches for lists
    _loadTransactions(uid);
    _loadWithdrawRequests(uid);
    _loadPaymentMethods(uid);
  }

  /// Pull-to-refresh handler.
  Future<void> _onRefresh() async {
    final uid = _uid;
    if (uid.isEmpty) return;
    // Run all refreshes in parallel; individual failures are caught by each method
    await Future.wait([
      WalletRepository.instance
          .refreshWallet(uid)
          .then((data) {
            if (mounted) setState(() => _walletData = data);
          })
          .catchError((_) {}),
      _loadTransactions(uid),
      _loadWithdrawRequests(uid),
      _loadPaymentMethods(uid),
    ]);
  }

  Future<void> _refreshWalletState({bool showLoading = false}) async {
    if (_uid.isEmpty) return;

    if (showLoading && mounted) {
      setState(() => _loadingWallet = true);
    }

    try {
      final data = await WalletRepository.instance.refreshWallet(_uid);
      if (mounted) {
        setState(() {
          _walletData = data;
          _loadingWallet = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingWallet = false);
      }
    }
  }

  Future<void> _loadTransactions(String uid) async {
    try {
      final list = await WalletRepository.instance.fetchTransactions(uid);
      if (mounted) {
        setState(() {
          _transactions = list;
          _loadingTx = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingTx = false);
      }
    }
  }

  Future<void> _loadWithdrawRequests(String uid) async {
    try {
      final list = await WalletRepository.instance.fetchWithdrawRequests(uid);
      if (mounted) {
        setState(() {
          _withdrawRequests = list;
          _loadingWd = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingWd = false);
      }
    }
  }

  Future<void> _loadPaymentMethods(String uid) async {
    try {
      final list = await WalletRepository.instance.fetchPaymentMethods(uid);
      if (mounted) {
        setState(() {
          _paymentMethods = list;
          _loadingPm = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingPm = false);
      }
    }
  }

  // ══════════════════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('المحفظة'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: const Color(0xFF7ED957),
          backgroundColor: const Color(0xFF1E1E1E),
          child: Column(
            children: [
              // Balance card
              _buildBalanceCard(),
              const SizedBox(height: 14),
              // Quick actions
              _buildQuickActions(),
              const SizedBox(height: 16),
              // Tab selector
              _buildTabSelector(),
              const SizedBox(height: 8),
              // Tab content
              Expanded(child: _buildTabContent()),
            ],
          ),
        ),
      ),
    );
  }

  // ── Balance card ─────────────────────────────────────

  Widget _buildBalanceCard() {
    final data = _walletData;
    final balance = data?.balance ?? 0;
    final pending = data?.pendingWithdraw ?? 0;
    final formatted = balance.toStringAsFixed(2);
    // ── سياسة محفظة الكابتن ──
    final minBalance = data?.minBalance ?? -300;
    final isDebt = balance < 0; // رصيد سالب → مديونية
    final isBlocked = balance <= minBalance; // عند حد الدين → إيقاف الرحلات
    final balanceColor = isDebt ? Colors.redAccent : AppColors.primary;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryContainer, AppColors.primaryBg],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDebt
              ? Colors.redAccent.withValues(alpha: 0.5)
              : AppColors.primary.withValues(alpha: 0.3),
        ),
        boxShadow: AppColors.shadowMd,
      ),
      child: Column(
        children: [
          // العنوان: مديونية عند الرصيد السالب
          Text(
            isDebt ? 'المديونية الحالية' : 'الرصيد الحالي',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 8),
          _loadingWallet
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : Text(
                  '$formatted ج.م',
                  style: AppTextStyles.amountLarge?.copyWith(
                    color: balanceColor,
                  ),
                ),
          // تسمية مديونية عند الرصيد السالب
          if (isDebt) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Text(
                'رصيد مدين — اشحن المحفظة',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          // بانر الإيقاف عند بلوغ حد الدين (-300)
          if (isBlocked) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.block, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تم إيقاف الرحلات — اشحن الآن',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (pending > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warningContainer,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Text(
                'مبلغ معلق: ${pending.toStringAsFixed(2)} ج.م',
                style: const TextStyle(color: AppColors.warning, fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              _statItem(
                'إجمالي الأرباح',
                data?.totalEarned ?? 0,
                AppColors.neonGreen,
              ),
              const SizedBox(width: 16),
              _statItem(
                'إجمالي المسحوب',
                data?.totalWithdrawn ?? 0,
                Colors.redAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Quick actions ────────────────────────────────────

  Widget _buildQuickActions() {
    final data = _walletData;
    final balance = data?.balance ?? 0;
    // السحب متاح فقط إذا كان الرصيد > 0 (سياسة المحفظة)
    final canWithdraw = balance > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              icon: Icons.add_circle_outline,
              label: 'إضافة رصيد',
              onTap: _showAddBalanceSheet,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              icon: Icons.credit_card,
              label: 'سحب رصيد',
              enabled: canWithdraw,
              onTap: _showWithdrawSheet,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              icon: Icons.account_balance,
              label: 'الأرباح',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EarningsScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    final Color fg = enabled ? AppColors.neonGreen : AppColors.textMuted;
    final Color labelColor = enabled ? Colors.white : AppColors.textMuted;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: enabled ? AppColors.glassBorder : Colors.white12,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: fg, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab selector ─────────────────────────────────────

  Widget _buildTabSelector() {
    const tabs = {
      WalletTab.transactions: 'التحويلات',
      WalletTab.withdraws: 'طلبات السحب',
      WalletTab.paymentMethods: 'طرق الدفع',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: tabs.entries.map((e) {
            final isSelected = _currentTab == e.key;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _currentTab = e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF7ED957)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Center(
                    child: Text(
                      e.value,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.black
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Tab content ──────────────────────────────────────

  Widget _buildTabContent() {
    switch (_currentTab) {
      case WalletTab.transactions:
        return _buildTransactionsTab();
      case WalletTab.withdraws:
        return _buildWithdrawsTab();
      case WalletTab.paymentMethods:
        return _buildPaymentMethodsTab();
    }
  }

  // ══════════════════════════════════════════════════════
  // Transactions Tab
  // ══════════════════════════════════════════════════════

  Widget _buildTransactionsTab() {
    if (_loadingTx) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF7ED957)),
      );
    }
    if (_transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.receipt_long,
              color: AppColors.textMuted,
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'لا توجد معاملات',
              style: TextStyle(color: AppColors.textMuted, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              'ستظهر معاملاتك المالية هنا بعد أول رحلة',
              style: TextStyle(
                color: AppColors.textMuted.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _transactions.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: Colors.white10),
      itemBuilder: (context, i) {
        final tx = _transactions[i];
        return _buildTxTile(tx);
      },
    );
  }

  Widget _buildTxTile(WalletTransaction tx) {
    final isPositive = tx.isCredit;
    final isPending = tx.status == 'pending';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isPending
                  ? AppColors.warning.withValues(alpha: 0.15)
                  : isPositive
                  ? AppColors.neonGreen.withValues(alpha: 0.15)
                  : Colors.redAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPending
                  ? Icons.access_time
                  : isPositive
                  ? Icons.arrow_downward
                  : Icons.arrow_upward,
              color: isPending
                  ? AppColors.warning
                  : isPositive
                  ? AppColors.neonGreen
                  : Colors.redAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Description + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(tx.createdAt),
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          // Amount + status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isPositive ? '+' : '-'}${tx.amount.toStringAsFixed(2)} ج.م',
                style: TextStyle(
                  color: isPending
                      ? const Color(0xFFF59E0B)
                      : isPositive
                      ? const Color(0xFF7ED957)
                      : Colors.redAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isPending)
                const Text(
                  'قيد الانتظار',
                  style: TextStyle(color: Color(0xFFF59E0B), fontSize: 10),
                ),
              if (tx.status == 'failed')
                const Text(
                  'فشل',
                  style: TextStyle(color: Colors.redAccent, fontSize: 10),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // Withdraw Requests Tab
  // ══════════════════════════════════════════════════════

  Widget _buildWithdrawsTab() {
    if (_loadingWd) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF7ED957)),
      );
    }
    if (_withdrawRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.hourglass_empty,
              color: AppColors.textMuted,
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'لا توجد طلبات سحب',
              style: TextStyle(color: AppColors.textMuted, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              'يمكنك طلب سحب رصيد من زر "سحب رصيد" بالأعلى',
              style: TextStyle(
                color: AppColors.textMuted.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    // Also show a summary card at the top
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        // Summary card
        _buildWithdrawSummary(),
        const SizedBox(height: 12),
        // Requests list
        ..._withdrawRequests.map((r) => _buildWithdrawTile(r)),
      ],
    );
  }

  Widget _buildWithdrawSummary() {
    final pendingCount = _withdrawRequests
        .where((r) => r.status == 'pending')
        .length;
    final totalWithdrawn = _withdrawRequests
        .where((r) => r.status == 'completed' || r.status == 'approved')
        .fold<double>(0, (s, r) => s + r.amount);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem(
            icon: Icons.hourglass_empty,
            value: '$pendingCount',
            label: 'قيد الانتظار',
          ),
          _summaryDivider(),
          _summaryItem(
            icon: Icons.check_circle,
            value: '${totalWithdrawn.toStringAsFixed(0)} ج.م',
            label: 'إجمالي المسحوب',
          ),
        ],
      ),
    );
  }

  Widget _summaryItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF7ED957), size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ],
    );
  }

  Widget _summaryDivider() {
    return Container(width: 1, height: 40, color: Colors.white10);
  }

  Widget _buildWithdrawTile(WithdrawRequest r) {
    Color statusColor;
    switch (r.status) {
      case 'pending':
        statusColor = const Color(0xFFF59E0B);
        break;
      case 'approved':
        statusColor = const Color(0xFF22C55E);
        break;
      case 'completed':
        statusColor = const Color(0xFF7ED957);
        break;
      case 'rejected':
        statusColor = Colors.redAccent;
        break;
      default:
        statusColor = AppColors.textMuted;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Status emoji
          Text(r.statusIcon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Amount + status badge
                Row(
                  children: [
                    Text(
                      '${r.amount.toStringAsFixed(2)} ج.م',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        r.statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Method
                Row(
                  children: [
                    Icon(
                      r.withdrawMethod == 'INSTAPAY'
                          ? Icons.send
                          : r.withdrawMethod == 'WALLET'
                          ? Icons.account_balance_wallet
                          : Icons.account_balance,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _withdrawMethodLabel(r.withdrawMethod),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Date
                Text(
                  _formatDate(r.createdAt),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _withdrawMethodLabel(String method) {
    switch (method) {
      case 'BANK':
        return 'تحويل بنكي';
      case 'INSTAPAY':
        return 'InstaPay';
      case 'WALLET':
        return 'محفظة إلكترونية';
      default:
        return method;
    }
  }

  Widget _statItem(String label, double amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              '${amount.toStringAsFixed(0)} ج.م',
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodTile(PaymentMethod pm) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: pm.isDefault
              ? const Color(0xFF7ED957).withValues(alpha: 0.5)
              : Colors.white10,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF7ED957).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(pm.icon, color: const Color(0xFF7ED957), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      pm.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (pm.isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF7ED957,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'أساسي',
                          style: TextStyle(
                            color: Color(0xFF7ED957),
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (pm.accountNumber != null)
                  Text(
                    pm.accountNumber!,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            color: const Color(0xFF1E1E1E),
            icon: const Icon(
              Icons.more_vert,
              color: AppColors.textMuted,
              size: 18,
            ),
            onSelected: (value) {
              if (value == 'default') {
                _setDefaultPaymentMethod(pm);
              } else if (value == 'delete') {
                _confirmDeletePaymentMethod(pm);
              }
            },
            itemBuilder: (_) => [
              if (!pm.isDefault)
                const PopupMenuItem(
                  value: 'default',
                  child: Row(
                    children: [
                      Icon(Icons.star, color: Color(0xFF7ED957), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'تعيين كأساسي',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text('حذف', style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // Payment Method management
  // ══════════════════════════════════════════════════════

  Future<void> _setDefaultPaymentMethod(PaymentMethod pm) async {
    if (_uid.isEmpty) return;
    try {
      await WalletRepository.instance.setDefaultPaymentMethod(_uid, pm.id);
      _loadPaymentMethods(_uid);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ أثناء تعيين طريقة الدفع الافتراضية'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _confirmDeletePaymentMethod(PaymentMethod pm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'حذف طريقة الدفع',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'هل تريد حذف "${pm.label}"؟',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (_uid.isEmpty) return;
              try {
                await WalletRepository.instance.deletePaymentMethod(
                  _uid,
                  pm.id,
                );
                _loadPaymentMethods(_uid);
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('حدث خطأ أثناء حذف طريقة الدفع'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: const Text('حذف', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddPaymentMethodSheet() async {
    final labelCtrl = TextEditingController();
    final accountCtrl = TextEditingController();
    final bankCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    // 0 = bank, 1 = vodafone_cash, 2 = instapay
    int selectedType = 0;
    final types = const [
      _PmType('bank', 'حساب بنكي', Icons.account_balance),
      _PmType('vodafone_cash', 'فودافون كاش', Icons.phone_android),
      _PmType('instapay', 'انستاباي', Icons.send),
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isBank = types[selectedType].type == 'bank';
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'إضافة طريقة دفع',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Type selector
                    Row(
                      children: types.asMap().entries.map((e) {
                        final t = e.value;
                        final selected = selectedType == e.key;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setSheetState(() => selectedType = e.key),
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFF7ED957)
                                    : Colors.white10,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xFF7ED957)
                                      : Colors.white24,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    t.icon,
                                    color: selected
                                        ? Colors.black
                                        : AppColors.textSecondary,
                                    size: 22,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    t.label,
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.black
                                          : AppColors.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    // Label
                    TextFormField(
                      controller: labelCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: _pmInputDecoration(
                        isBank ? 'اسم الحساب البنكي' : 'الاسم / الوصف',
                        isBank ? 'مثال: حساب الأهلي' : 'مثال: رقمي الشخصي',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'الرجاء إدخال وصف';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    // Account number
                    TextFormField(
                      controller: accountCtrl,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: _pmInputDecoration(
                        isBank ? 'رقم الحساب' : 'رقم الحساب / المحفظة',
                        'مثال: 1234567890',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'الرجاء إدخال رقم الحساب';
                        }
                        return null;
                      },
                    ),
                    if (isBank) ...[
                      const SizedBox(height: 14),
                      // Bank name
                      TextFormField(
                        controller: bankCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: _pmInputDecoration(
                          'اسم البنك',
                          'مثال: البنك الأهلي المصري',
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7ED957),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          if (_uid.isEmpty) return;
                          final navigator = Navigator.of(context);
                          try {
                            await WalletRepository.instance.addPaymentMethod(
                              _uid,
                              type: types[selectedType].type,
                              label: labelCtrl.text.trim(),
                              accountNumber: accountCtrl.text.trim(),
                              bankName: isBank ? bankCtrl.text.trim() : null,
                              isDefault: _paymentMethods.isEmpty,
                            );
                            if (mounted) navigator.pop();
                            _loadPaymentMethods(_uid);
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'حدث خطأ أثناء إضافة طريقة الدفع',
                                  ),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        },
                        child: const Text(
                          'حفظ',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _pmInputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppColors.textSecondary),
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textMuted),
      filled: true,
      fillColor: Colors.white10,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  // ══════════════════════════════════════════════════════
  // Payment Methods Tab
  // ══════════════════════════════════════════════════════

  Widget _buildPaymentMethodsTab() {
    if (_loadingPm) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF7ED957)),
      );
    }
    if (_paymentMethods.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.payment, color: AppColors.textMuted, size: 48),
            const SizedBox(height: 12),
            const Text(
              'لا توجد طرق دفع',
              style: TextStyle(color: AppColors.textMuted, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              'أضف طريقة دفع جديدة لاستخدامها في السحب',
              style: TextStyle(
                color: AppColors.textMuted.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        const SizedBox(height: 4),
        ..._paymentMethods.map((pm) => _buildPaymentMethodTile(pm)),
        const SizedBox(height: 16),
        // Add new button
        Center(
          child: TextButton.icon(
            onPressed: _showAddPaymentMethodSheet,
            icon: const Icon(Icons.add_circle, color: Color(0xFF7ED957)),
            label: const Text(
              'إضافة طريقة دفع',
              style: TextStyle(color: Color(0xFF7ED957)),
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // Add Balance bottom sheet (Kashier)
  // ══════════════════════════════════════════════════════

  void _showAddBalanceSheet() {
    final amountCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    // طريقة الدفع المختارة: 'card' (بطاقة بنكية) أو 'wallet' (محفظة)
    String selectedMethod = 'card';
    // ── سياسة محفظة الكابتن (تحقق محلي: يعتمد على minTopUp من الباك إند مع fallback 10) ──
    final minTopUp = _walletData?.minTopUp ?? 10;
    final maxBalance = _walletData?.maxBalance ?? 1500;
    final currentBalance = _walletData?.balance ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'إضافة رصيد',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'سيتم شحن المحفظة عبر Kashier (بطاقة ائتمان / محفظة إلكترونية)',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Amount
                    TextFormField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('المبلغ', 'مثال: 100'),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'الرجاء إدخال المبلغ';
                        }
                        final amount = double.tryParse(v);
                        if (amount == null || amount <= 0) {
                          return 'مبلغ غير صالح';
                        }
                        if (amount < minTopUp) {
                          return 'أقل مبلغ للشحن هو ${minTopUp.toStringAsFixed(0)} ج.م';
                        }
                        if (currentBalance + amount > maxBalance) {
                          return 'لا يمكن أن يتجاوز رصيد المحفظة ${maxBalance.toStringAsFixed(0)} ج.م';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    // طريقة الشحن
                    const Text(
                      'طريقة الشحن',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _PaymentMethodChip(
                            label: 'بطاقة بنكية',
                            icon: Icons.credit_card,
                            selected: selectedMethod == 'card',
                            onTap: () =>
                                setSheetState(() => selectedMethod = 'card'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PaymentMethodChip(
                            label: 'محفظة',
                            icon: Icons.account_balance_wallet,
                            selected: selectedMethod == 'wallet',
                            onTap: () =>
                                setSheetState(() => selectedMethod = 'wallet'),
                          ),
                        ),
                      ],
                    ),
                    if (selectedMethod == 'wallet') ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        maxLength: 11,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration(
                          'رقم المحفظة (رقم التليفون)',
                          'مثال: 01001234567',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'الرجاء إدخال رقم المحفظة';
                          }
                          if (v.trim().length < 11) {
                            return 'رقم المحفظة يجب أن يكون 11 أرقام على الأقل';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 24),
                    // Submit
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setSheetState(() => isLoading = true);

                                final amount = double.parse(amountCtrl.text);
                                final uid =
                                    AuthService.instance.currentUser?.uid ?? '';

                                if (uid.isEmpty) {
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (mounted) {
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'تعذر تحديد المستخدم، حاول لاحقاً',
                                        ),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  }
                                  return;
                                }

                                try {
                                  // Step 1: Call backend to initiate payment session
                                  final response = await ApiService.instance
                                      .initiatePayment(
                                        amount: amount,
                                        paymentMethod: selectedMethod,
                                        walletPhone: selectedMethod == 'wallet'
                                            ? phoneCtrl.text.trim()
                                            : null,
                                      );

                                  // ── استخراج رابط الدفع بأمان (بدون as String صارم) ──
                                  final paymentUrl =
                                      (response['paymentUrl'] ??
                                              response['sessionUrl'] ??
                                              response['checkoutUrl'])
                                          ?.toString();
                                  final sessionId =
                                      response['sessionId']?.toString() ?? '';

                                  // لا نفتح WebView إلا برابط http(s) صالح
                                  final trimmedUrl = paymentUrl?.trim() ?? '';
                                  final isHttpUrl =
                                      trimmedUrl.startsWith('http://') ||
                                      trimmedUrl.startsWith('https://');
                                  if (trimmedUrl.isEmpty || !isHttpUrl) {
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        this.context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'فشل الحصول على رابط الدفع، حاول مرة أخرى',
                                          ),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                    }
                                    return;
                                  }

                                  if (ctx.mounted) Navigator.pop(ctx);

                                  // تأكد أن شاشة المحفظة ما زالت موجودة قبل فتح الـ WebView.
                                  if (!mounted) return;

                                  // Step 2: Launch WebView with payment session
                                  final success = await Navigator.push<bool>(
                                    this.context,
                                    MaterialPageRoute(
                                      builder: (_) => KashierCheckoutWebView(
                                        checkoutUrl: trimmedUrl,
                                        sessionId: sessionId,
                                      ),
                                    ),
                                  );

                                  if (!mounted) return;

                                  final orderId =
                                      response['orderId']?.toString() ?? '';
                                  final shouldConfirm =
                                      success == true ||
                                      (orderId.isNotEmpty &&
                                          sessionId.isNotEmpty);

                                  if (shouldConfirm) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        this.context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('جاري تأكيد الدفع…'),
                                          backgroundColor: Color(0xFFF59E0B),
                                        ),
                                      );
                                    }

                                    try {
                                      await ApiService.instance.confirmTopUp(
                                        orderId: orderId,
                                        sessionId: sessionId,
                                      );
                                      await _refreshWalletState(
                                        showLoading: true,
                                      );
                                      await Future.wait([
                                        _loadTransactions(uid),
                                        _loadWithdrawRequests(uid),
                                        _loadPaymentMethods(uid),
                                      ]);

                                      if (mounted) {
                                        final balance =
                                            _walletData?.balance ?? 0;
                                        ScaffoldMessenger.of(
                                          this.context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'تم شحن المحفظة بنجاح! الرصيد الحالي: ${balance.toStringAsFixed(2)} ج.م',
                                            ),
                                            backgroundColor: Color(0xFF22C55E),
                                          ),
                                        );
                                      }
                                    } catch (_) {
                                      await _refreshWalletState(
                                        showLoading: true,
                                      );
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          this.context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'تم إغلاق الدفع أو تأكيده، وتم تحديث الرصيد من الخادم',
                                            ),
                                            backgroundColor:
                                                Colors.orangeAccent,
                                          ),
                                        );
                                      }
                                    }
                                  } else {
                                    await _refreshWalletState(
                                      showLoading: true,
                                    );
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        this.context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'فشلت عملية الدفع، يرجى المحاولة مرة أخرى',
                                          ),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                    }
                                  }
                                } on ApiException catch (e) {
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (mounted) {
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text(e.message),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (mounted) {
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'تعذر شحن المحفظة، حاول مرة أخرى',
                                        ),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7ED957),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Text(
                                'دفع عبر Kashier',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════
  // Withdraw bottom sheet
  // ══════════════════════════════════════════════════════

  void _showWithdrawSheet() {
    final amountCtrl = TextEditingController();
    final accountCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final uid = AuthService.instance.currentUser?.uid ?? '';
    bool isLoading = false;
    String withdrawMethod = 'WALLET'; // 'WALLET' or 'INSTAPAY'
    final availableBalance = _walletData?.balance ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'طلب سحب رصيد',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'اختر طريقة السحب وأدخل المبلغ',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // طريقة السحب
                    const Text(
                      'طريقة السحب',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _PaymentMethodChip(
                            label: 'محفظة إلكترونية',
                            icon: Icons.account_balance_wallet,
                            selected: withdrawMethod == 'WALLET',
                            onTap: () {
                              setSheetState(() {
                                withdrawMethod = 'WALLET';
                                accountCtrl.clear();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PaymentMethodChip(
                            label: 'InstaPay',
                            icon: Icons.send,
                            selected: withdrawMethod == 'INSTAPAY',
                            onTap: () {
                              setSheetState(() {
                                withdrawMethod = 'INSTAPAY';
                                accountCtrl.clear();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Amount
                    TextFormField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('المبلغ', 'مثال: 500'),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'الرجاء إدخال المبلغ';
                        }
                        final amount = double.tryParse(v);
                        if (amount == null || amount <= 0) {
                          return 'مبلغ غير صالح';
                        }
                        if (amount > availableBalance) {
                          return 'المبلغ يتجاوز الرصيد المتاح (${availableBalance.toStringAsFixed(2)} ج.م)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    // Account identifier (dynamic based on method)
                    TextFormField(
                      controller: accountCtrl,
                      keyboardType: withdrawMethod == 'WALLET'
                          ? TextInputType.phone
                          : TextInputType.text,
                      maxLength: withdrawMethod == 'WALLET' ? 11 : null,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        withdrawMethod == 'WALLET'
                            ? 'رقم المحفظة (رقم التليفون)'
                            : 'معرف إنستاباي (InstaPay ID)',
                        withdrawMethod == 'WALLET'
                            ? 'مثال: 01001234567'
                            : 'مثال: user@instapay',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return withdrawMethod == 'WALLET'
                              ? 'الرجاء إدخال رقم المحفظة'
                              : 'الرجاء إدخال معرف InstaPay';
                        }
                        if (withdrawMethod == 'WALLET' &&
                            v.trim().length < 11) {
                          return 'رقم المحفظة يجب أن يكون 11 أرقام على الأقل';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    // Submit button with double-tap protection
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setSheetState(() => isLoading = true);

                                String? errorMsg;
                                try {
                                  await WalletRepository.instance
                                      .submitWithdrawRequest(
                                        uid,
                                        amount: double.parse(amountCtrl.text),
                                        withdrawMethod: withdrawMethod,
                                        walletPhone: withdrawMethod == 'WALLET'
                                            ? accountCtrl.text.trim()
                                            : null,
                                        instapayId: withdrawMethod == 'INSTAPAY'
                                            ? accountCtrl.text.trim()
                                            : null,
                                      );
                                } on ApiException catch (e) {
                                  errorMsg = e.message;
                                } catch (e) {
                                  errorMsg =
                                      'حدث خطأ غير متوقع أثناء إرسال الطلب';
                                }

                                if (!ctx.mounted) return;

                                if (errorMsg != null) {
                                  setSheetState(() => isLoading = false);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(errorMsg),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  }
                                  return;
                                }

                                Navigator.pop(ctx);
                                _loadWithdrawRequests(uid);
                                setState(
                                  () => _currentTab = WalletTab.withdraws,
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('تم إرسال طلب السحب بنجاح'),
                                      backgroundColor: Color(0xFF22C55E),
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7ED957),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Text(
                                'إرسال الطلب',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: AppColors.textSecondary),
      hintStyle: TextStyle(color: AppColors.textMuted),
      filled: true,
      fillColor: const Color(0xFF0D131E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF7ED957)),
      ),
    );
  }

  // ──────────────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────────────

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _PmType {
  final String type;
  final String label;
  final IconData icon;
  const _PmType(this.type, this.label, this.icon);
}

/// Chip لاختيار طريقة الشحن (فيزا / محفظة) داخل الـ Bottom Sheet.
class _PaymentMethodChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentMethodChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? AppColors.primary : Colors.white70,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.primary : Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
