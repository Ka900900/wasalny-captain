import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

import 'package:waslny_captain/core/models/notification_models.dart';
import 'package:waslny_captain/features/wallet/wallet_screen.dart';
import 'package:waslny_captain/features/notifications/notifications_screen.dart';

/// Global navigator key used for notification‑driven navigation.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

FirebaseAnalytics? _analytics;
FirebaseAnalyticsObserver? _analyticsObserver;

/// Must be called once after [Firebase.initializeApp] completes.
void initAnalytics() {
  _analytics = FirebaseAnalytics.instance;
  _analyticsObserver = FirebaseAnalyticsObserver(analytics: _analytics!);
}

/// Firebase Analytics instance – `null` until [initAnalytics] is called.
FirebaseAnalytics? get analytics => _analytics;

/// Firebase Analytics observer – `null` until [initAnalytics] is called.
FirebaseAnalyticsObserver? get analyticsObserver => _analyticsObserver;

/// Handle a notification tap – navigate to the appropriate screen.
void handleNotificationTap(AppNotification notification) {
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
void handleForegroundNotification(AppNotification notification) {
  final nav = navigatorKey.currentState;
  if (nav == null || nav.context.mounted == false) return;

  final context = nav.context;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(notification.title),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'عرض',
        onPressed: () => handleNotificationTap(notification),
      ),
    ),
  );
}
