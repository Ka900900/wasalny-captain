import 'package:flutter/material.dart';
import 'package:kashier_flutter_sdk/kashier_flutter_sdk.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:waslny_captain/core/navigation.dart';
import 'package:waslny_captain/core/services/notification_service.dart';
import 'package:waslny_captain/core/theme/app_theme.dart';
import 'package:waslny_captain/core/services/settings_service.dart';
import 'package:waslny_captain/core/widgets/route_transitions.dart';
import 'package:waslny_captain/core/utils/logger.dart';
import 'package:waslny_captain/features/auth/login_screen.dart';
import 'package:waslny_captain/features/auth/registration_screen.dart';
import 'package:waslny_captain/features/auth/vehicle_info_screen.dart';
import 'package:waslny_captain/features/profile/settings_screen.dart';
import 'package:waslny_captain/features/splash/splash_screen.dart';
import 'package:waslny_captain/features/home/home_screen.dart';
import 'package:waslny_captain/features/notifications/notifications_screen.dart';
import 'package:waslny_captain/features/safety/safety_screen.dart';

/// [runApp] is called immediately without awaiting any async init.
/// All service initialisation (Firebase, Crashlytics, FCM, Settings,
/// Kashier) is delegated to [SplashScreen] so the UI appears instantly
/// and the user sees a smooth branded experience while the app warms up.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  setupLogging();
  // Register the top‑level FCM background handler as early as possible so it
  // is available even if the app is launched from a notification while killed.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
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
        navigatorObservers: <NavigatorObserver>[
          if (analyticsObserver != null) analyticsObserver!,
        ],
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
        late final RegistrationScreen registrationScreen;
        final args = settings.arguments;
        if (args is Map) {
          registrationScreen = RegistrationScreen(
            phoneNumber: args['phoneNumber'] as String?,
            googleName: args['name'] as String?,
            googleEmail: args['email'] as String?,
            googlePhotoUrl: args['photoUrl'] as String?,
          );
        } else {
          registrationScreen = RegistrationScreen(
            phoneNumber: args as String?,
          );
        }
        return RouteTransitions.slideUp(registrationScreen);
      case '/vehicle-info':
        late final VehicleInfoScreen vehicleInfoScreen;
        final vArgs = settings.arguments;
        if (vArgs is Map) {
          vehicleInfoScreen = VehicleInfoScreen(
            phoneNumber: vArgs['phoneNumber'] as String?,
            googleName: vArgs['name'] as String?,
            googleEmail: vArgs['email'] as String?,
            googlePhotoUrl: vArgs['photoUrl'] as String?,
          );
        } else {
          vehicleInfoScreen = const VehicleInfoScreen();
        }
        return RouteTransitions.slideUp(vehicleInfoScreen);
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
