import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:kashier_flutter_sdk/kashier_flutter_sdk.dart';

import 'package:waslny_captain/firebase_options.dart';
import 'package:waslny_captain/core/navigation.dart';
import 'package:waslny_captain/core/services/auth_service.dart';
import 'package:waslny_captain/core/services/api_service.dart';
import 'package:waslny_captain/core/services/kashier_service.dart';
import 'package:waslny_captain/core/services/notification_service.dart';
import 'package:waslny_captain/core/services/settings_service.dart';
import 'package:waslny_captain/core/theme/app_theme.dart';
import 'package:waslny_captain/features/home/home_screen.dart';
import 'package:waslny_captain/features/auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scale;
  late final Animation<double> _glowPulse;

  late final Future<void> _initializationFuture;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );
    _scale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );
    _glowPulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 1.0, curve: Curves.easeInOutSine),
      ),
    );
    _controller.forward();
    _initializationFuture = _initializeApp();
  }

  Future<void> _initializeApp() async {
    // ── 1. Firebase MUST be ready before anything else ──
    await _initFirebase();

    // ── 2. Initialise Firebase-dependent services ──
    initAnalytics();

    // ── 3. All other services run in parallel with a timeout guard ──
    final List<Future<void>> tasks = [];

    if (!kIsWeb) {
      tasks.add(_timed('Crashlytics', _initCrashlytics()));
    }

    tasks.add(_timed('ErrorWidget', _initErrorWidget()));
    tasks.add(_timed('Settings', SettingsService.instance.initialize()));
    tasks.add(_timed('AuthToken', ApiService.instance.loadToken()));
    tasks.add(_timed('Notifications', _initNotificationService()));

    if (!kIsWeb) {
      tasks.add(_timed('Kashier', _initKashier()));
    }

    // Ensure a minimum splash duration so the animation feels polished
    tasks.add(Future.delayed(const Duration(milliseconds: 1800)));

    await Future.wait(tasks);
  }

  /// Runs [future] with an 8‑second timeout, logging start/finish time and
  /// any error. Errors and timeouts never abort the other initialisation
  /// tasks – we simply log and continue so the splash screen can proceed.
  Future<void> _timed(String name, Future<void> future) async {
    final stopwatch = Stopwatch()..start();
    // ignore: avoid_print
    print('[init] $name ▶ started');
    try {
      await future.timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          // ignore: avoid_print
          print(
            '[init] $name ⏱ TIMEOUT after ${stopwatch.elapsed.inMilliseconds}ms',
          );
        },
      );
      // ignore: avoid_print
      print('[init] $name ✔ done in ${stopwatch.elapsed.inMilliseconds}ms');
    } catch (e, stack) {
      // ignore: avoid_print
      print(
        '[init] $name ❌ error after ${stopwatch.elapsed.inMilliseconds}ms: $e',
      );
      // ignore: avoid_print
      print(stack);
    } finally {
      stopwatch.stop();
    }
  }

  Future<void> _initFirebase() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (e) {
      if (e.code != 'duplicate-app') {
        rethrow;
      }
    }
  }

  Future<void> _initCrashlytics() async {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      originalOnError?.call(errorDetails);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  Future<void> _initErrorWidget() async {
    ErrorWidget.builder = (FlutterErrorDetails details) => Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: const Color(0xFF081014),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFFF5A5F),
                size: 64,
              ),
              const SizedBox(height: 20),
              const Text(
                'حدث خطأ غير متوقع',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF7FAFC),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'يرجى إعادة المحاولة',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFC5D0D8),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _initKashier() async {
    KashierSDK.initialize(mode: KashierMode.live, language: KashierLanguage.ar);

    KashierService.instance.configure(useCloudFunction: true, isLiveMode: true);
  }

  Future<void> _initNotificationService() async {
    final notifService = NotificationService.instance;
    notifService.onNotificationTap = handleNotificationTap;
    notifService.onForegroundNotification = handleForegroundNotification;
    await notifService.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildSplashScreen(BuildContext context, {Widget? errorContent}) {
    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.7 + _glowPulse.value * 0.3,
                colors: [
                  AppColors.primary.withValues(alpha: 0.12 * _fadeIn.value),
                  AppColors.primaryBg,
                  AppColors.primaryBg,
                ],
              ),
            ),
            child: Opacity(
              opacity: _fadeIn.value,
              child: Transform.scale(
                scale: _scale.value,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Premium animated logo with enhanced glow
                    AnimatedBuilder(
                      animation: _glowPulse,
                      builder: (context, child) {
                        return Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(
                                  alpha: 0.5 * _glowPulse.value,
                                ),
                                blurRadius: 80 * _glowPulse.value,
                                spreadRadius: 15 * _glowPulse.value,
                              ),
                              BoxShadow(
                                color: AppColors.primaryLight.withValues(
                                  alpha: 0.2 * _glowPulse.value,
                                ),
                                blurRadius: 120 * _glowPulse.value,
                                spreadRadius: 25 * _glowPulse.value,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/appstore.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24.0), // AppSpacing.xxxl
                    // Premium app name with gradient effect
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          AppColors.primaryGradient.createShader(bounds),
                      child: Text(
                        'Waslny',
                        style: Theme.of(context).textTheme.displayLarge
                            ?.copyWith(color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 4.0), // AppSpacing.sm
                    Text(
                      'Captain',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.textSecondary,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 64.0), // AppSpacing.huge
                    // Loading indicator or error content
                    errorContent ??
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                            backgroundColor: AppColors.primary.withValues(
                              alpha: 0.15,
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // Show a more user-friendly error on the splash screen itself
          return _buildSplashScreen(
            context,
            errorContent: Column(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'فشل في تهيئة التطبيق',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                Text(
                  snapshot.error.toString(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.done) {
          final bool isLoggedIn = AuthService.instance.isLoggedIn;
          // Use a post-frame callback to schedule navigation after the build is complete.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => isLoggedIn
                      ? const CaptainHomeScreen()
                      : const LoginScreen(),
                ),
              );
            }
          });
        }

        // While initializing, show the splash screen
        return _buildSplashScreen(context);
      },
    );
  }
}
