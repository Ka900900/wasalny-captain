import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:kashier_flutter_sdk/kashier_flutter_sdk.dart';

import 'package:waslny_captain/firebase_options.dart';
import 'package:waslny_captain/core/theme/app_theme.dart';
import 'package:waslny_captain/core/services/kashier_service.dart';
import 'package:waslny_captain/core/services/notification_service.dart';
import 'package:waslny_captain/core/services/settings_service.dart';
import 'package:waslny_captain/core/models/notification_models.dart';
import 'package:waslny_captain/core/widgets/route_transitions.dart';
import 'package:waslny_captain/features/auth/login_screen.dart';
import 'package:waslny_captain/features/auth/registration_screen.dart';
import 'package:waslny_captain/features/auth/vehicle_info_screen.dart';
import 'package:waslny_captain/features/profile/settings_screen.dart';
import 'package:waslny_captain/features/splash/splash_screen.dart';
import 'package:waslny_captain/features/home/home_screen.dart';
import 'package:waslny_captain/features/wallet/wallet_screen.dart';
import 'package:waslny_captain/features/notifications/notifications_screen.dart';
import 'package:waslny_captain/features/safety/safety_screen.dart';

/// Global navigator key used for notification‑driven navigation.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Firebase Analytics instance for screen tracking and events.
final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

/// Firebase Analytics observer for automatic screen navigation tracking.
final FirebaseAnalyticsObserver analyticsObserver = FirebaseAnalyticsObserver(
  analytics: analytics,
);

/// Handle a notification tap – navigate to the appropriate screen.
void _handleNotificationTap(AppNotification notification) {
  final nav = navigatorKey.currentState;
  if (nav == null) return;

  // Pop back to root first to avoid nested routes
  nav.popUntil((route) => route.isFirst);

  switch (notification.type) {
    case NotificationType.newRide:
    case NotificationType.tripUpdate:
      nav.pushReplacementNamed('/home');
    case NotificationType.walletUpdate:
      nav.push(MaterialPageRoute(builder: (_) => const WalletScreen()));
    case NotificationType.promotion:
      nav.push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
  }
}

/// Handle a notification received while the app is in the foreground.
void _handleForegroundNotification(AppNotification notification) {
  final nav = navigatorKey.currentState;
  if (nav == null || nav.context.mounted == false) return;

  final context = nav.context;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(notification.title),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'عرض',
        onPressed: () => _handleNotificationTap(notification),
      ),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ──────────────────────────────────────────────
  // Firebase Core
  // ──────────────────────────────────────────────
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ──────────────────────────────────────────────
  // Firebase Crashlytics – Global error handling
  // ──────────────────────────────────────────────
  if (!kIsWeb) {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      // Chain to the default handler so errors still show in debug
      originalOnError?.call(errorDetails);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  // ── Replace the default red error screen with a dark-themed one ──
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

  // ──────────────────────────────────────────────
  // Firebase Cloud Messaging – Initialisation
  // ──────────────────────────────────────────────
  final notifService = NotificationService.instance;
  notifService.onNotificationTap = _handleNotificationTap;
  notifService.onForegroundNotification = _handleForegroundNotification;
  await notifService.initialize();
  await SettingsService.instance.initialize();

  // ──────────────────────────────────────────────
  // Kashier Payment SDK – Initialisation
  // ──────────────────────────────────────────────
  if (!kIsWeb) {
    KashierSDK.initialize(
      mode: KashierMode.test, // ← change to KashierMode.live for production
      language: KashierLanguage.ar,
    );

    KashierService.instance.configure(
      useCloudFunction: true,
      isLiveMode: false,
    );
  }

  // ──────────────────────────────────────────────
  // Launch the app
  // ──────────────────────────────────────────────
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    SettingsService.instance.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    SettingsService.instance.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return KashierPaymentProvider(
      child: MaterialApp(
        title: 'Waslny Captain',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: SettingsService.instance.themeMode,
        navigatorObservers: <NavigatorObserver>[analyticsObserver],
        initialRoute: '/splash',
        onGenerateRoute: _onGenerateRoute,
      ),
    );
  }

  /// Central route generator with animated transitions.
  static Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/splash':
        return RouteTransitions.fade(const SplashScreen());
      case '/login':
        return RouteTransitions.slideUp(const LoginScreen());
      case '/registration':
        final phoneNumber = settings.arguments as String? ?? '';
        return RouteTransitions.slideUp(
          RegistrationScreen(phoneNumber: phoneNumber),
        );
      case '/vehicle-info':
        return RouteTransitions.slideUp(const VehicleInfoScreen());
      case '/home':
        return RouteTransitions.slideHorizontal(const CaptainHomeScreen());
      case '/notifications':
        return RouteTransitions.slideUp(const NotificationsScreen());
      case '/settings':
        return RouteTransitions.slideUp(const SettingsScreen());
      case '/safety':
        return RouteTransitions.slideUp(const SafetyScreen());
      default:
        return RouteTransitions.fade(const SplashScreen());
    }
  }
}
