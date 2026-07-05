import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:waslny_captain/core/models/notification_models.dart';

/// Repository that manages FCM tokens and in-app notifications in Firestore.
///
/// Data is organised as:
/// - `drivers/{uid}/tokens/{fcmToken}` → FCM device tokens
/// - `drivers/{uid}/notifications/{notifId}` → historical notifications
class NotificationRepository {
  NotificationRepository._();
  static final NotificationRepository instance = NotificationRepository._();

  // ──────────────────────────────────────────────────────
  // Firestore helpers
  // ──────────────────────────────────────────────────────

  DocumentReference<Map<String, dynamic>> _driverRef(String uid) =>
      FirebaseFirestore.instance.collection('drivers').doc(uid);

  CollectionReference<Map<String, dynamic>> _tokensRef(String uid) =>
      _driverRef(uid).collection('tokens');

  CollectionReference<Map<String, dynamic>> _notificationsRef(String uid) =>
      _driverRef(uid).collection('notifications');

  // ──────────────────────────────────────────────────────
  // FCM Token management
  // ──────────────────────────────────────────────────────

  /// Save the current FCM token under the driver's tokens sub‑collection.
  ///
  /// The token ID is the token itself so re‑saving overwrites the same doc.
  Future<void> saveToken(String uid) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await _tokensRef(uid).doc(token).set({
      'token': token,
      'platform': 'mobile',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remove a token from Firestore (e.g. on logout).
  Future<void> removeToken(String uid) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    try {
      await _tokensRef(uid).doc(token).delete();
    } catch (_) {
      // Ignore if doc doesn't exist
    }
  }

  // ──────────────────────────────────────────────────────
  // In‑app notifications
  // ──────────────────────────────────────────────────────

  /// Fetch all notifications for the driver, newest first.
  Future<List<AppNotification>> fetchNotifications(
    String uid, {
    int limit = 50,
  }) async {
    try {
      final snap = await _notificationsRef(uid)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((d) => AppNotification.fromMap(d.id, d.data()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Stream notifications in real time.
  Stream<List<AppNotification>> streamNotifications(
    String uid, {
    int limit = 50,
  }) {
    return _notificationsRef(uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AppNotification.fromMap(d.id, d.data()))
            .toList());
  }

  /// Save a notification to Firestore after receiving it via FCM.
  Future<void> addNotification(
    String uid,
    AppNotification notification,
  ) async {
    await _notificationsRef(uid).add(notification.toMap());
  }

  /// Mark a single notification as read.
  Future<void> markAsRead(String uid, String notifId) async {
    await _notificationsRef(uid).doc(notifId).update({
      'isRead': true,
    });
  }

  /// Mark all unread notifications as read.
  Future<void> markAllAsRead(String uid) async {
    final unread = await _notificationsRef(uid)
        .where('isRead', isEqualTo: false)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  /// Return the count of unread notifications.
  Future<int> unreadCount(String uid) async {
    try {
      final snap = await _notificationsRef(uid)
          .where('isRead', isEqualTo: false)
          .count()
          .get();
      return snap.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Stream the unread count in real time.
  Stream<int> streamUnreadCount(String uid) {
    return _notificationsRef(uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }
}
