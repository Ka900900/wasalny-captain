import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:waslny_captain/core/services/auth_service.dart';
import 'package:waslny_captain/core/services/api_service.dart';
import 'package:waslny_captain/core/services/sound_service.dart';
import 'package:waslny_captain/core/repositories/notification_repository.dart';
import 'package:waslny_captain/core/models/notification_models.dart';
import 'package:waslny_captain/core/utils/logger.dart';

/// Android notification channel used for incoming ride alerts.
const String _rideChannelId = 'ride_alerts';
const String _rideChannelName = 'تنبيهات الرحلات';
const int _rideNotificationId = 1001;

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure plugins (audioplayers, local notifications) are usable in the
  // background isolate.
  WidgetsFlutterBinding.ensureInitialized();

  logInfo(
    'NotificationService',
    '[FCM Background] ${message.messageId} — ${message.notification?.title}',
  );

  // Show a local notification so the captain sees the alert even when the app
  // is terminated / in the background.
  await _showLocalNotificationFromMessage(message);

  // Play the distinctive ride‑alert sound so the captain's attention is drawn
  // immediately. The OS keeps the audio player alive while the isolate runs.
  final type = NotificationType.fromString(
    message.data['type'] as String? ?? 'promotion',
  );
  if (type == NotificationType.newRide) {
    await SoundService.instance.playLoopingAlert();
  }
}

/// Display a high‑priority local notification for the given FCM message.
Future<void> _showLocalNotificationFromMessage(RemoteMessage message) async {
  try {
    final notification = message.notification;
    final data = message.data;
    final title =
        notification?.title ?? data['title'] as String? ?? 'وصلني كابتن';
    final body = notification?.body ?? data['body'] as String? ?? '';

    const androidDetails = AndroidNotificationDetails(
      _rideChannelId,
      _rideChannelName,
      channelDescription: 'تنبيهات فورية عند وصول رحلة جديدة للكابتن',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('ride_alert'),
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
    );
    const iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'ride_alert.mp3',
    );
    const platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await FlutterLocalNotificationsPlugin().show(
      _rideNotificationId,
      title,
      body,
      platformDetails,
      payload: data['type'] as String? ?? 'promotion',
    );
  } catch (e) {
    logError('NotificationService', 'showLocalNotification failed: $e', e);
  }
}

class NotificationService {
  // ── Singleton ───────────────────────────────────────
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openSub;
  StreamSubscription<String>? _tokenSub;

  String? _deviceToken;
  String? get deviceToken => _deviceToken;

  void Function(AppNotification notification)? onNotificationTap;
  void Function(AppNotification notification)? onForegroundNotification;

  /// Whether FCM listeners are currently active.
  bool _enabled = false;

  Future<void> initialize() async {
    if (_enabled) return; // already running
    if (kIsWeb) {
      _enabled = true;
      return;
    }

    _messaging = FirebaseMessaging.instance;

    await _initLocalNotifications();

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    try {
      await _requestPermissions().timeout(const Duration(seconds: 6));
    } catch (e) {
      logError(
        'NotificationService',
        'requestPermission failed/timed out: $e',
        e,
      );
    }

    try {
      await _refreshToken().timeout(const Duration(seconds: 6));
    } catch (e) {
      logError('NotificationService', 'getToken failed/timed out: $e', e);
    }

    _tokenSub = _messaging!.onTokenRefresh.listen(_onTokenRefresh);
    await _handleInitialMessage();
    _openSub = FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
    _foregroundSub = FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    _enabled = true;
  }

  /// Enable notifications: re-initialise FCM listeners and get a fresh token.
  Future<void> enable() async {
    if (_enabled) return;
    await initialize();
  }

  /// Disable notifications: cancel all listeners, delete the FCM token.
  Future<void> disable() async {
    if (!_enabled) return;
    _disposeSubscriptions();
    try {
      await _messaging?.deleteToken();
    } catch (_) {}
    await removeToken();
    _enabled = false;
  }

  /// Cancel all active subscriptions.
  void _disposeSubscriptions() {
    _foregroundSub?.cancel();
    _foregroundSub = null;
    _openSub?.cancel();
    _openSub = null;
    _tokenSub?.cancel();
    _tokenSub = null;
  }

  /// Legacy alias for external callers that used [dispose].
  void dispose() => _disposeSubscriptions();

  // ── Permission ──────────────────────────────────────

  /// Initialise the local notifications plugin and create the Android channel
  /// used for incoming ride alerts.
  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );

    // Create the high‑priority Android channel (required for importance.max).
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _rideChannelId,
        _rideChannelName,
        description: 'تنبيهات فورية عند وصول رحلة جديدة للكابتن',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('ride_alert'),
      ),
    );
  }

  /// Called when the user taps a local notification shown by this plugin.
  void _onLocalNotificationTapped(NotificationResponse response) {
    final type = NotificationType.fromString(response.payload ?? 'promotion');
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      title: '',
      body: '',
      createdAt: DateTime.now(),
    );
    onNotificationTap?.call(notification);
  }

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

  // ── Token management ────────────────────────────────

  Future<void> _refreshToken() async {
    _deviceToken = await _messaging!.getToken();
    await _saveTokenToFirestore();
    // If the captain is already signed in (e.g. cold start → splash → home),
    // register the token with the backend too so ride alerts keep working.
    if (AuthService.instance.isLoggedIn) {
      unawaited(registerTokenWithBackend());
    }
  }

  Future<void> _onTokenRefresh(String token) async {
    _deviceToken = token;
    await _saveTokenToFirestore();
    await registerTokenWithBackend();
  }

  /// Send the current FCM token to the custom backend so the server can target
  /// this captain with real ride-alert push notifications.
  ///
  /// Safe to call at any time (e.g. right after login, or when the token
  /// refreshes). If no token is cached yet, a fresh one is fetched first.
  /// Failures are logged and swallowed so they never break the surrounding flow.
  Future<void> registerTokenWithBackend() async {
    String? token = _deviceToken;
    if (token == null || token.isEmpty) {
      try {
        token = await _messaging?.getToken();
      } catch (e) {
        logError('NotificationService', 'getToken failed: $e', e);
      }
      if (token == null || token.isEmpty) return;
      _deviceToken = token;
      await _saveTokenToFirestore();
    }
    try {
      await ApiService.instance
          .updateFcmTokenToServer(token)
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      logError('NotificationService', 'registerTokenWithBackend failed: $e', e);
    }
  }

  Future<void> _saveTokenToFirestore() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || _deviceToken == null) return;
    try {
      await NotificationRepository.instance
          .saveToken(uid)
          .timeout(const Duration(seconds: 6));
    } catch (e) {
      logError(
        'NotificationService',
        'saveToken to Firestore failed/timed out: $e',
        e,
      );
    }
  }

  Future<void> removeToken() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    await NotificationRepository.instance.removeToken(uid);
  }

  // ── Message handling ────────────────────────────────

  Future<void> _handleInitialMessage() async {
    final message = await _messaging!.getInitialMessage();
    if (message != null) {
      final notification = _parseRemoteMessage(message);
      if (notification != null && onNotificationTap != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onNotificationTap!(notification);
        });
      }
    }
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    final notification = _parseRemoteMessage(message);
    if (notification != null && onNotificationTap != null) {
      onNotificationTap!(notification);
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final notification = _parseRemoteMessage(message);
    if (notification != null) {
      // Show a local notification (so it appears in the system tray even while
      // the app is open) and play the distinctive alert sound.
      _showLocalNotificationFromMessage(message);
      if (notification.type == NotificationType.newRide) {
        SoundService.instance.playLoopingAlert();
      } else {
        SoundService.instance.playNotificationAlert();
      }
      _saveNotification(notification);
      onForegroundNotification?.call(notification);
    }
  }

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

  Future<void> _saveNotification(AppNotification notification) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    await NotificationRepository.instance.addNotification(uid, notification);
  }
}
