import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:waslny_captain/core/models/chat_message.dart';

/// Service that manages the real-time chat between the captain and the
/// passenger for a single active ride.
///
/// Firestore structure:
///   `chats/{rideId}`            — room metadata (riderId, driverId, lastMessage…)
///   `chats/{rideId}/messages`   — ordered message sub-collection (createdAt asc)
///
/// The chat room is created by the backend when the captain accepts the ride
/// (`POST /api/v1/driver/accept-ride/:rideId` → Firestore `chats/{rideId}`).
/// This service only reads/writes messages; it never fakes data.
class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<QuerySnapshot>? _messagesSubscription;

  /// Returns a real-time stream of messages for [rideId], ordered oldest→newest.
  ///
  /// Throws a clear exception if the user is not authenticated or Firestore
  /// is unreachable, so the UI can surface the real error to testers.
  Stream<List<ChatMessage>> messagesStream(String rideId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('غير مسجّل الدخول — لا يمكن فتح المحادثة');
    }
    return _db
        .collection('chats')
        .doc(rideId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => ChatMessage.fromDoc(doc)).toList();
        })
        .handleError((e, stack) {
          debugPrint('❌ ChatService.messagesStream error (ride $rideId): $e');
          debugPrint(stack.toString());
          // Re-throw so the StreamBuilder's error builder can show it.
          throw e;
        });
  }

  /// Send a text message from the current captain to the passenger.
  ///
  /// [receiverId] is the passenger's Firebase UID (the ride's `riderId`).
  /// Returns the written document id on success.
  Future<String> sendMessage({
    required String rideId,
    required String receiverId,
    required String text,
  }) async {
    final uid = _auth.currentUser?.uid;
    final trimmed = text.trim();
    if (uid == null) {
      throw Exception('غير مسجّل الدخول — لا يمكن إرسال الرسالة');
    }
    if (trimmed.isEmpty) {
      throw Exception('نص الرسالة فارغ');
    }

    try {
      final batch = _db.batch();

      // 1) الرسالة نفسها
      final msgRef = _db
          .collection('chats')
          .doc(rideId)
          .collection('messages')
          .doc();
      batch.set(msgRef, {
        'rideId': rideId,
        'senderId': uid,
        'receiverId': receiverId,
        'text': trimmed,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // 2) تحديث بيانات الغرفة (آخر رسالة + وقتها)
      final roomRef = _db.collection('chats').doc(rideId);
      batch.update(roomRef, {
        'lastMessage': trimmed,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': uid,
      });

      await batch.commit();
      debugPrint('💬 ChatService.sendMessage ok (ride $rideId)');
      return msgRef.id;
    } catch (e, stack) {
      debugPrint('❌ ChatService.sendMessage error (ride $rideId): $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }

  /// Stop any active listener (call when leaving the chat screen).
  void dispose() {
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
  }
}
