import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:waslny_captain/core/services/auth_service.dart';
import 'package:waslny_captain/core/services/sound_service.dart';
import 'package:waslny_captain/core/repositories/notification_repository.dart';
import 'package:waslny_captain/core/models/notification_models.dart';

/// Top‑level background message handler required by Firebase Messaging.
///
/// Must be a top‑level function (not a method inside a class).
/// This handler is never called on web – FCM is not supported there.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // ignore: avoid_print
  print(
    '[FCM Background] ${message.messageId} — ${message.notification?.title}',
  );
}

/// Centralised service that manages Firebase Cloud Messaging lifecycle.
///
/// ## Typical setup in main.dart
/// ```dart
/// final notifService = NotificationService.instance;
/// notifService.onNotificationTap = (notification) {
///   // navigate based on notification.type
/// };
/// notifService.onForegroundNotification = (notification) {
///   // show in‑app banner
/// };
/// await notifService.initialize();
/// ```
class NotificationService {
  // ── Singleton ───────────────────────────────────────
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  /// Lazily‑initialised FCM instance.  `null` on web (FCM not supported).
  FirebaseMessaging? _messaging;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openSub;
  StreamSubscription<String>? _tokenSub;

  /// The latest FCM device token.
  String? _deviceToken;
  String? get deviceToken => _deviceToken;

  /// Called when the user taps a notification (from background or terminated).
  /// The handler should navigate based on [AppNotification.type] and [data].
  void Function(AppNotification notification)? onNotificationTap;

  /// Called when a notification arrives while the app is in the foreground.
  /// Use this to show an in‑app banner, SnackBar, or dialog.
  void Function(AppNotification notification)? onForegroundNotification;

  /// Whether the service has been initialised.
  bool _initialized = false;

  // ────────────────────────────────────────────────────
  // Initialisation
  // ────────────────────────────────────────────────────

  /// Initialise FCM: register background handler, request permission,
  /// obtain token, and start listeners.
  ///
  /// Call this once in `main()` after `Firebase.initializeApp()`.
  ///
  /// On the web platform FCM is not supported, so this method is a no‑op.
  Future<void> initialize() async {
    if (_initialized) return;

    // FCM is not supported on web – skip all FCM operations.
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    // Initialise the FCM instance (must be done after the kIsWeb guard)
    _messaging = FirebaseMessaging.instance;

    // 1. Register the top‑level background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 2. Request notification permissions
    await _requestPermissions();

    // 3. Obtain the device token
    await _refreshToken();

    // 4. Listen for token refresh
    _tokenSub = _messaging!.onTokenRefresh.listen(_onTokenRefresh);

    // 5. Handle message that opened the app from a terminated state
    await _handleInitialMessage();

    // 6. Listen for messages that open the app from background
    _openSub = FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    // 7. Listen for foreground messages
    _foregroundSub = FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    _initialized = true;
  }

  /// Dispose all listeners. Call on logout or when shutting down.
  void dispose() {
    _foregroundSub?.cancel();
    _openSub?.cancel();
    _tokenSub?.cancel();
    _initialized = false;
  }

  // ────────────────────────────────────────────────────
  // Permission
  // ────────────────────────────────────────────────────

  Future<void> _requestPermissions() async {
    await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );
  }

  // ────────────────────────────────────────────────────
  // Token management
  // ────────────────────────────────────────────────────

  /// Fetch the current token and save it to Firestore if the user is logged in.
  Future<void> _refreshToken() async {
    _deviceToken = await _messaging!.getToken();
    await _saveTokenToFirestore();
  }

  /// Called by [FirebaseMessaging.onTokenRefresh] when the token changes.
  Future<void> _onTokenRefresh(String token) async {
    _deviceToken = token;
    await _saveTokenToFirestore();
  }

  /// Persist the current token to Firestore under the logged‑in driver.
  Future<void> _saveTokenToFirestore() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || _deviceToken == null) return;
    await NotificationRepository.instance.saveToken(uid);
  }

  /// Remove the token from Firestore (call on logout).
  Future<void> removeToken() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    await NotificationRepository.instance.removeToken(uid);
  }

  // ────────────────────────────────────────────────────
  // Message handling
  // ────────────────────────────────────────────────────

  /// Check if the app was launched by tapping a notification while terminated.
  Future<void> _handleInitialMessage() async {
    final message = await _messaging!.getInitialMessage();
    if (message != null) {
      final notification = _parseRemoteMessage(message);
      if (notification != null && onNotificationTap != null) {
        // Defer navigation until the widget tree is ready.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onNotificationTap!(notification);
        });
      }
    }
  }

  /// Called when the user taps a notification while the app is in background.
  void _onMessageOpenedApp(RemoteMessage message) {
    final notification = _parseRemoteMessage(message);
    if (notification != null && onNotificationTap != null) {
      onNotificationTap!(notification);
    }
  }

  /// Called when a push arrives while the app is in the foreground.
  void _onForegroundMessage(RemoteMessage message) {
    final notification = _parseRemoteMessage(message);
    if (notification != null) {
      // Play notification sound
      SoundService.instance.playNotificationAlert();
      // Save to Firestore
      _saveNotification(notification);
      // Notify the UI layer
      onForegroundNotification?.call(notification);
    }
  }

  // ────────────────────────────────────────────────────
  // Helpers
  // ────────────────────────────────────────────────────

  /// Convert a [RemoteMessage] into the app‑level [AppNotification].
  AppNotification? _parseRemoteMessage(RemoteMessage message) {
    final data = message.data;
    final notification = message.notification;

    if (data.isEmpty && notification == null) return null;

    final typeStr = data['type'] as String? ?? 'promotion';
    final type = NotificationType.fromString(typeStr);

    return AppNotification(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      title: notification?.title ?? data['title'] as String? ?? '',
      body: notification?.body ?? data['body'] as String? ?? '',
      data: data.isNotEmpty ? data : null,
      createdAt: DateTime.now(),
    );
  }

  /// Persist an incoming notification to Firestore.
  Future<void> _saveNotification(AppNotification notification) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    await NotificationRepository.instance.addNotification(uid, notification);
  }
}
