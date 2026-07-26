import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:waslny_captain/core/services/auth_service.dart';
import 'package:waslny_captain/core/services/api_service.dart';
import 'package:waslny_captain/core/repositories/driver_repository.dart';
import 'package:waslny_captain/core/theme/app_theme.dart';
import 'package:waslny_captain/features/auth/verification_pending_screen.dart';

class OTPScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;

  const OTPScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _pinController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  int _resendSeconds = 30;
  bool _canResend = false;
  String? _currentVerificationId;
  bool _isResending = false;

  late final AnimationController _animController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animController,
            curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
          ),
        );
    _animController.forward();
    _startResendTimer();
  }

  void _startResendTimer() {
    setState(() {
      _resendSeconds = 30;
      _canResend = false;
    });
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        if (_resendSeconds > 0) {
          _resendSeconds--;
        } else {
          _canResend = true;
        }
      });
      return _resendSeconds > 0 && mounted;
    });
  }

  Future<void> _resendCode() async {
    if (_isResending) return;
    setState(() => _isResending = true);

    _startResendTimer();
    debugPrint("📤 Resending OTP to ${widget.phoneNumber}");

    await AuthService.instance.verifyPhoneNumber(
      widget.phoneNumber,
      (newVerificationId) {
        if (!mounted) return;
        setState(() {
          _currentVerificationId = newVerificationId;
          _isResending = false;
        });
        debugPrint("✅ New verificationId received: $newVerificationId");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إعادة إرسال رمز التحقق')),
        );
      },
      (error) {
        if (!mounted) return;
        setState(() => _isResending = false);
        debugPrint("❌ Resend failed: $error");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppColors.error),
        );
      },
    );
  }

  Future<void> _verifyOTP() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final verificationId = _currentVerificationId ?? widget.verificationId;
      debugPrint("🔐 Using verificationId: $verificationId");

      // 1. Verify OTP and sign in with Firebase
      final firebaseToken = await AuthService.instance.verifyOTP(
        verificationId,
        _pinController.text.trim(),
      );

      // 2. Exchange Firebase ID Token → App JWT (via backend)
      try {
        await AuthService.instance.loginWithBackend(firebaseToken);
      } catch (e) {
        debugPrint('loginWithBackend failed: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تم تسجيل الدخول في Firebase لكن فشل الربط مع الخادم: $e',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }

      // 3. Check if profile exists → Registration or Home
      final uid = AuthService.instance.currentUser?.uid;
      if (uid != null) {
        final existingProfile = await DriverRepository.instance.getProfile(uid);
        if (mounted) {
          if (existingProfile == null) {
            // First login – go to Registration
            Navigator.pushReplacementNamed(
              context,
              '/registration',
              arguments: widget.phoneNumber,
            );
          } else {
            // Existing user – check verification status
            await _navigateBasedOnVerification();
          }
        }
      } else {
        // No uid after login – fallback to login
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
        }
      }
    } on FirebaseAuthException catch (e) {
      debugPrint("❌ كود خطأ الفايربيز: ${e.code}");
      debugPrint("❌ الرسالة الصريحة: ${e.message}");
      setState(() {
        _errorMessage = e.message ?? _mapFirebaseAuthError(e);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ خطأ عام آخر: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// يستدعي API البروفايل ويوجّه المستخدم بناءً على حالة التحقق.
  Future<void> _navigateBasedOnVerification() async {
    try {
      final data = await ApiService.instance.getProfile();
      if (!mounted) return;

      final role = data['role'] as String? ?? 'RIDER';
      if (role == 'RIDER') {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
        return;
      }

      final driverProfile = data['driverProfile'] as Map<String, dynamic>?;
      final status =
          driverProfile?['verificationStatus'] as String? ?? 'PENDING';

      switch (status) {
        case 'APPROVED':
          Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
          break;
        case 'REJECTED':
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => VerificationPendingScreen(
                rejectionReason:
                    driverProfile?['rejectionReason'] as String?,
              ),
            ),
            (_) => false,
          );
          break;
        default: // PENDING
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => const VerificationPendingScreen(),
            ),
            (_) => false,
          );
          break;
      }
    } catch (_) {
      // آمن: في حال فشل الـ API نوجّه للـ Home
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
      }
    }
  }

  String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return 'رمز التحقق غير صحيح. حاول مرة أخرى.';
      case 'session-expired':
        return 'انتهت صلاحية الجلسة. أعد إرسال رمز التحقق.';
      case 'too-many-requests':
        return 'لقد تجاوزت عدد المحاولات المسموح بها. حاول لاحقاً.';
      default:
        return e.message ?? 'فشل التحقق من الرمز. حاول مرة أخرى.';
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 52,
      height: 60,
      textStyle: const TextStyle(
        fontSize: 22,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.bold,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.border),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.bottomLeft,
            radius: 1.6,
            colors: [
              AppColors.primary.withValues(alpha: 0.06),
              AppColors.primaryBg,
              AppColors.primaryBg,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: Form(
                key: _formKey,
                child: FadeTransition(
                  opacity: _fadeIn,
                  child: SlideTransition(
                    position: _slideUp,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Animated shield icon
                        AnimatedBuilder(
                          animation: _animController,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle:
                                  math.sin(
                                    _animController.value * math.pi * 2,
                                  ) *
                                  0.05,
                              child: child,
                            );
                          },
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withValues(alpha: 0.12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.25,
                                  ),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.shield_outlined,
                              color: AppColors.primary,
                              size: 45,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),

                        // Premium title
                        Text(
                          'تحقق من رقم هاتفك',
                          style: AppTextStyles.headlineLarge?.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'أدخل الرمز المكون من 6 أرقام المرسل إلى',
                          style: AppTextStyles.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '+20 ${widget.phoneNumber}',
                          style: AppTextStyles.titleMedium?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // Premium OTP input with shadow
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd,
                            ),
                            boxShadow: AppColors.shadowSm,
                          ),
                          child: Pinput(
                            length: 6,
                            controller: _pinController,
                            autofocus: true,
                            defaultPinTheme: defaultPinTheme.copyWith(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSm,
                                ),
                                border: Border.all(color: AppColors.border),
                              ),
                            ),
                            focusedPinTheme: defaultPinTheme.copyWith(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSm,
                                ),
                                border: Border.all(
                                  color: _errorMessage != null
                                      ? AppColors.error
                                      : AppColors.primary,
                                  width: 2,
                                ),
                              ),
                            ),
                            onChanged: (_) {
                              if (_errorMessage != null) {
                                setState(() => _errorMessage = null);
                              }
                            },
                            validator: (value) {
                              if (value == null || value.length < 6) {
                                return 'الرجاء إدخال الرمز كاملاً';
                              }
                              return null;
                            },
                          ),
                        ),

                        // Error message
                        if (_errorMessage != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.errorContainer,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusSm,
                              ),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],

                        const SizedBox(height: AppSpacing.xxxl),

                        // Premium verify button
                        Container(
                          width: double.infinity,
                          height: AppSpacing.buttonHeightLg,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusLg,
                            ),
                            boxShadow: AppColors.shadowPrimary,
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _verifyOTP,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusLg,
                                ),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: AppColors.primaryBg,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : const Text('تحقق الآن'),
                          ),
                        ),

                        const SizedBox(height: AppSpacing.xl),

                        // Resend section with premium styling
                        _canResend
                            ? Container(
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusMd,
                                  ),
                                ),
                                child: TextButton.icon(
                                  onPressed: _isResending ? null : _resendCode,
                                  icon: _isResending
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.primary,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.refresh,
                                          color: AppColors.primary,
                                          size: 18,
                                        ),
                                  label: Text(
                                    _isResending
                                        ? 'جارٍ الإرسال...'
                                        : 'إعادة إرسال الرمز',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              )
                            : Text(
                                'إعادة الإرسال بعد $_resendSeconds ثانية',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                ),
                              ),

                        const SizedBox(height: AppSpacing.sm),

                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'تغيير رقم الهاتف',
                            style: AppTextStyles.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
