import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:waslny_captain/core/design_system/design_system.dart';
import 'package:waslny_captain/core/services/api_service.dart';
import 'package:waslny_captain/core/services/auth_service.dart';

/// شاشة "في انتظار التحقق" تظهر بعد تسجيل الكابتن أو إذا كانت حالته PENDING.
///
/// إذا تم تمرير [rejectionReason] تُعرض كشاشة رفض مع سبب الرفض،
/// وإلا تُعرض كشاشة انتظار مراجعة.
class VerificationPendingScreen extends StatefulWidget {
  /// سبب الرفض (إذا كان non‑null تعرض الشاشة كـ "تم رفض الطلب").
  final String? rejectionReason;

  const VerificationPendingScreen({super.key, this.rejectionReason});

  @override
  State<VerificationPendingScreen> createState() =>
      _VerificationPendingScreenState();
}

class _VerificationPendingScreenState extends State<VerificationPendingScreen> {
  bool _isChecking = false;
  bool _isLoggingOut = false;

  // ──────────────────────────────────────────────
  // تسجيل الخروج
  // ──────────────────────────────────────────────

  Future<void> _confirmAndLogout() async {
    HapticFeedback.mediumImpact();

    final bool confirmed = await WaslnyDialog.confirm(
      context: context,
      title: 'تسجيل الخروج',
      message: 'هل أنت متأكد أنك تريد تسجيل الخروج؟',
      confirmLabel: 'تسجيل الخروج',
      cancelLabel: 'إلغاء',
      isDestructive: true,
    );

    if (confirmed != true) return;

    setState(() => _isLoggingOut = true);

    try {
      await AuthService.instance.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoggingOut = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تسجيل الخروج: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ──────────────────────────────────────────────
  // تحديث الحالة من الباك إند
  // ──────────────────────────────────────────────

  /// يستدعي API البروفايل ويتحقق من `driverProfile.verificationStatus`.
  /// إذا صار APPROVED يوجّه للصفحة الرئيسية، وإلا يبقى في الشاشة.
  Future<void> _checkStatus() async {
    setState(() => _isChecking = true);

    try {
      final data = await ApiService.instance.getProfile();
      if (!mounted) return;

      final driverProfile = data['driverProfile'] as Map<String, dynamic>?;
      final status = driverProfile?['verificationStatus'] as String? ?? 'PENDING';

      if (status == 'APPROVED') {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
        return;
      }

      // PENDING أو REJECTED — نبقى في الشاشة
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'REJECTED'
                  ? 'لا يزال طلبك مرفوضًا. تواصل مع الدعم للحصول على المساعدة.'
                  : 'طلبك لا يزال قيد المراجعة. حاول مرة أخرى لاحقًا.',
            ),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر التحقق من الحالة: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  // ──────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool isRejected = widget.rejectionReason != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: AppSpacing.xxxl),

                  // ── Icon ───────────────────────────────
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: isRejected
                          ? AppColors.error.withValues(alpha: 0.12)
                          : AppColors.warning.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isRejected
                          ? Icons.cancel_rounded
                          : Icons.access_time_rounded,
                      size: 48,
                      color: isRejected ? AppColors.error : AppColors.warning,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  // ── Title ──────────────────────────────
                  Text(
                    isRejected ? 'تم رفض الطلب' : 'طلبك قيد المراجعة',
                    style: AppTextStyles.headlineMedium,
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // ── Subtitle ───────────────────────────
                  Text(
                    isRejected
                        ? 'للأسف، لم يتم الموافقة على طلب تسجيلك.'
                        : 'سيتم مراجعة بياناتك من قبل فريقنا خلال 24-48 ساعة',
                    style: AppTextStyles.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // ── Rejection reason ───────────────────
                  if (isRejected && widget.rejectionReason!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'سبب الرفض:',
                            style: AppTextStyles.labelLarge?.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            widget.rejectionReason!,
                            style: AppTextStyles.bodyMedium?.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xxxl),

                  // ── Refresh status button ──────────────
                  WaslnyButton.primary(
                    label: 'تحديث الحالة',
                    icon: Icons.refresh_rounded,
                    loading: _isChecking,
                    onPressed: _isChecking ? null : _checkStatus,
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // ── Logout button ──────────────────────
                  WaslnyButton.danger(
                    label: 'تسجيل الخروج',
                    icon: Icons.logout_rounded,
                    loading: _isLoggingOut,
                    onPressed: _isLoggingOut ? null : _confirmAndLogout,
                  ),

                  const SizedBox(height: AppSpacing.xxxl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
