import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:waslny_captain/core/design_system/design_system.dart';
import 'package:waslny_captain/core/services/api_service.dart';
import 'package:waslny_captain/core/services/auth_service.dart';
import 'package:waslny_captain/core/services/document_upload_service.dart';
import 'package:waslny_captain/features/verification/verification_screen.dart';

/// شاشة "في انتظار التحقق" تظهر بعد تسجيل الكابتن أو إذا كانت حالته PENDING.
///
/// - إذا كان [initialRejectionReason] non‑null تُعرض الشاشة كشاشة رفض.
/// - عند فتح الشاشة يتم استدعاء API البروفايل تلقائياً للتحقق من آخر حالة.
/// - إذا صارت الحالة APPROVED تظهر رسالة تهنئة ثم التوجيه للصفحة الرئيسية.
/// - إذا كانت الحالة REJECTED تُعرض تفاصيل الرفض مع زر "إعادة رفع المستندات".
class VerificationPendingScreen extends StatefulWidget {
  /// سبب الرفض المبدئي (يُستخدم قبل اكتمال استدعاء API البروفايل).
  final String? initialRejectionReason;

  const VerificationPendingScreen({super.key, this.initialRejectionReason});

  @override
  State<VerificationPendingScreen> createState() =>
      _VerificationPendingScreenState();
}

class _VerificationPendingScreenState extends State<VerificationPendingScreen> {
  // ── حالة الشاشة ────────────────────────────────────
  bool _isChecking = false;
  bool _isLoggingOut = false;
  bool _isResubmitting = false;

  /// الحالية المستخلصة من API البروفايل (PENDING / APPROVED / REJECTED).
  String _status = 'PENDING';

  /// سبب الرفض (يُملأ من API البروفايل).
  String? _rejectionReason;

  /// هل تم التحقق التلقائي عند فتح الشاشة؟
  bool _initialCheckDone = false;

  @override
  void initState() {
    super.initState();

    // نبدأ بقيمة rejectionReason المبدئية إن وُجدت
    if (widget.initialRejectionReason != null) {
      _status = 'REJECTED';
      _rejectionReason = widget.initialRejectionReason;
    }

    // التحقق التلقائي من الحالة عند فتح الشاشة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkStatus(showSnackbarOnPending: false);
    });
  }

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
  // التحقق من الحالة من الباك إند
  // ──────────────────────────────────────────────

  /// يستدعي API البروفايل ويتحقق من `driverProfile.verificationStatus`.
  ///
  /// - APPROVED → يعرض رسالة تهنئة ثم يوجّه للصفحة الرئيسية.
  /// - REJECTED → يُحدّث واجهة الرفض مع سبب الرفض.
  /// - PENDING → يبقى في شاشة الانتظار.
  Future<void> _checkStatus({bool showSnackbarOnPending = true}) async {
    setState(() => _isChecking = true);

    try {
      final data = await ApiService.instance.getProfile();
      if (!mounted) return;

      final driverProfile = data['driverProfile'] as Map<String, dynamic>?;
      final status =
          driverProfile?['verificationStatus'] as String? ?? 'PENDING';
      final rejectionReason = driverProfile?['rejectionReason'] as String?;

      if (status == 'APPROVED') {
        // ── تهانينا! الحساب مُفعّل ──
        await _showCongratulationsDialog();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
        }
        return;
      }

      // تحديث حالة الرفض إن وُجدت
      if (status == 'REJECTED' && mounted) {
        setState(() {
          _status = 'REJECTED';
          _rejectionReason = rejectionReason;
        });
        return;
      }

      // PENDING — نبقى في الشاشة
      if (mounted) {
        setState(() => _status = 'PENDING');
        if (showSnackbarOnPending) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('طلبك لا يزال قيد المراجعة. حاول مرة أخرى لاحقًا.'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
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
      if (mounted) {
        setState(() {
          _isChecking = false;
          _initialCheckDone = true;
        });
      }
    }
  }

  // ──────────────────────────────────────────────
  // رسالة التهنئة (APPROVED)
  // ──────────────────────────────────────────────

  /// عرض نافذة تهنئة عند الموافقة على طلب التسجيل.
  Future<void> _showCongratulationsDialog() async {
    await WaslnyDialog.show(
      context: context,
      title: 'تهانينا! 🎉',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.md),
          Icon(Icons.verified_rounded, size: 80, color: AppColors.success),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'تم تفعيل حسابك بنجاح!',
            style: AppTextStyles.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'يمكنك الآن البدء في استقبال الرحلات. مرحباً بك في واسلني كابتن!',
            style: AppTextStyles.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        WaslnyButton.primary(
          label: 'بدء الرحلات',
          icon: Icons.directions_car_rounded,
          onPressed: () => Navigator.of(context).pop(),
          expanded: true,
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // إعادة تقديم الطلب (بعد الرفض)
  // ──────────────────────────────────────────────

  /// فتح شاشة التحقق لإعادة رفع المستندات بعد الرفض.
  Future<void> _reUploadDocuments() async {
    final result = await Navigator.of(context).push<VerificationResult>(
      MaterialPageRoute(builder: (_) => const VerificationScreen()),
    );

    if (result == null || !mounted) return;

    // إرسال المستندات المُحدَّثة إلى الباك إند
    setState(() => _isResubmitting = true);

    try {
      await ApiService.instance.resubmitApplication(
        idCardUrl: result.uploadedUrls[UploadDocType.idFront],
        idCardBackUrl: result.uploadedUrls[UploadDocType.idBack],
        licenseUrl: result.uploadedUrls[UploadDocType.license],
        faceUrl: result.uploadedUrls[UploadDocType.face],
      );

      if (!mounted) return;

      // العودة لشاشة الانتظار (تم التقديم بنجاح)
      setState(() {
        _status = 'PENDING';
        _rejectionReason = null;
        _isResubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إرسال المستندات بنجاح. سيتم مراجعتها قريباً.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isResubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل إعادة تقديم الطلب: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ──────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool isRejected = _status == 'REJECTED';

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
                        ? 'للأسف، لم تتم الموافقة على طلب تسجيلك بسبب مشاكل في المستندات.'
                        : 'سيتم مراجعة بياناتك من قبل فريقنا خلال 24-48 ساعة',
                    style: AppTextStyles.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // ── Rejection reason ───────────────────
                  if (isRejected &&
                      _rejectionReason != null &&
                      _rejectionReason!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
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
                            _rejectionReason!,
                            style: AppTextStyles.bodyMedium?.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xxl),

                  // ── Re-upload button (REJECTED only) ──
                  if (isRejected) ...[
                    WaslnyButton.primary(
                      label: 'إعادة رفع المستندات',
                      icon: Icons.upload_file_rounded,
                      loading: _isResubmitting,
                      onPressed: _isResubmitting ? null : _reUploadDocuments,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // ── Refresh status button ──────────────
                  WaslnyButton.outline(
                    label: 'تحديث الحالة',
                    icon: Icons.refresh_rounded,
                    loading: _isChecking,
                    onPressed: _isChecking ? null : () => _checkStatus(),
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
