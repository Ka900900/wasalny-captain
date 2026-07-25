import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:waslny_captain/core/network/api_exceptions.dart';
import 'package:waslny_captain/core/services/auth_service.dart';
import 'package:waslny_captain/core/services/api_service.dart';
import 'package:waslny_captain/core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;

  late final AnimationController _animController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;
  late final Animation<double> _carFloat;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
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
    _carFloat = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeInOutSine),
      ),
    );
    _animController.forward();
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      // 1. Sign in with Google → Firebase → Backend
      final result = await AuthService.instance.signInWithGoogle();

      if (!mounted) return;

      // 2. Extract Google profile data for pre‑filling
      final displayName = result['displayName'] as String? ?? '';
      final email = result['email'] as String? ?? '';
      final photoUrl = result['photoUrl'] as String? ?? '';

      // 2b. Check backend phone — if it's a "firebase:" placeholder, the user
      //     needs to provide a real phone number before continuing.
      final captain = result['captain'] as Map<String, dynamic>?;
      final backendPhone = captain?['phone'] as String?;
      final needsPhoneEntry =
          backendPhone == null ||
          backendPhone.isEmpty ||
          backendPhone.startsWith('firebase:');

      // 3. Check if driver is registered on the backend → Onboarding or Home
      final isRegistered = await ApiService.instance.isDriverRegistered();
      if (mounted) {
        if (isRegistered && !needsPhoneEntry) {
          // Existing user with real phone – go to Home
          Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
        } else if (isRegistered && needsPhoneEntry) {
          // Registered but has placeholder phone – prompt for real phone
          final realPhone = await _showPhoneEntryDialog();
          if (realPhone != null && realPhone.isNotEmpty && mounted) {
            await ApiService.instance.updatePhoneNumber(phoneNumber: realPhone);
            Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
          }
        } else {
          // First login – go to onboarding with Google data pre‑filled
          String? phoneForRegistration;
          if (!needsPhoneEntry) {
            phoneForRegistration = backendPhone;
          } else {
            // Prompt for real phone before vehicle-info
            final realPhone = await _showPhoneEntryDialog();
            if (realPhone == null || realPhone.isEmpty) {
              // User cancelled phone entry
              if (mounted) setState(() => _isLoading = false);
              return;
            }
            phoneForRegistration = realPhone;
            // Update phone on backend
            await ApiService.instance.updatePhoneNumber(phoneNumber: realPhone);
          }
          if (mounted) {
            Navigator.pushReplacementNamed(
              context,
              '/vehicle-info',
              arguments: <String, dynamic>{
                'name': displayName,
                'email': email,
                'photoUrl': photoUrl,
                'phoneNumber': phoneForRegistration,
              },
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(_mapFirebaseError(e));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e.toString());
    }
  }

  String _mapFirebaseError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'cancelled':
          return 'تم إلغاء تسجيل الدخول.';
        case 'account-exists-with-different-credential':
          return 'يوجد حساب آخر بنفس البريد الإلكتروني.';
        case 'invalid-credential':
          return 'فشل التحقق من بيانات جوجل. حاول مرة أخرى.';
        case 'user-disabled':
          return 'تم تعطيل حسابك. تواصل مع الدعم.';
        case 'too-many-requests':
          return 'تم تجاوز عدد المحاولات المسموح بها. حاول لاحقًا.';
        case 'network-request-failed':
          return 'تحقق من اتصال الإنترنت ثم أعد المحاولة.';
        default:
          return error.message ?? 'فشل تسجيل الدخول بحساب جوجل.';
      }
    }
    return error.toString();
  }

  /// Shows a dialog asking the user to enter their real phone number.
  /// Returns the phone number string if confirmed, or null if cancelled.
  Future<String?> _showPhoneEntryDialog() async {
    final phoneController = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('رقم الهاتف'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'يجب إدخال رقم هاتف حقيقي لإتمام التسجيل.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  hintText: '+212 6XX XX XX XX',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final phone = phoneController.text.trim();
                if (phone.isEmpty) return;
                // Basic validation: must start with + and have 8-15 digits
                final clean = phone.replaceAll(RegExp(r'[\s\-]'), '');
                if (!RegExp(r'^\+?\d{8,15}$').hasMatch(clean)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('صيغة رقم الهاتف غير صحيحة'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }
                Navigator.of(context).pop(phone);
              },
              child: const Text('تأكيد'),
            ),
          ],
        );
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.8,
            colors: [
              AppColors.primary.withValues(alpha: 0.08),
              AppColors.primaryBg,
              AppColors.primaryBg,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated logo
                  AnimatedBuilder(
                    animation: _carFloat,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(
                          0,
                          -8 * math.sin(_carFloat.value * math.pi * 2),
                        ),
                        child: Opacity(opacity: _fadeIn.value, child: child),
                      );
                    },
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/appstore.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // Welcome title
                  FadeTransition(
                    opacity: _fadeIn,
                    child: SlideTransition(
                      position: _slideUp,
                      child: Column(
                        children: [
                          Text(
                            'مرحباً بك',
                            style: AppTextStyles.displayMedium?.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'سجل دخولك لبدء استقبال الرحلات',
                            style: AppTextStyles.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.huge),

                  // Google Sign-In button
                  FadeTransition(
                    opacity: _fadeIn,
                    child: SlideTransition(
                      position: _slideUp,
                      child: Column(
                        children: [
                          _buildGoogleButton(),
                          const SizedBox(height: AppSpacing.xxl),

                          // Terms
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.md,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.card.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusMd,
                              ),
                            ),
                            child: Text(
                              'بالمتابعة، أنت توافق على شروط الخدمة وسياسة الخصوصية',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.labelSmall?.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Google "G" logo widget with fallback icon.
  static Widget _googleLogo({double size = 24}) {
    return Image.network(
      'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
      width: size,
      height: size,
      errorBuilder: (_, __, ___) =>
          Icon(Icons.g_mobiledata, size: size + 4, color: AppColors.googleRed),
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: AppSpacing.buttonHeightLg,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _signInWithGoogle,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isLoading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.primary,
                  ),
                )
              : _googleLogo(),
        ),
        label: Text(
          'تسجيل الدخول باستخدام Google',
          style: AppTextStyles.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 2,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            side: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      ),
    );
  }
}
