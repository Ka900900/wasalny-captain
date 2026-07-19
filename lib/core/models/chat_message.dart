/// A single chat message exchanged between the captain and the passenger
/// during an active ride.
///
/// Messages are stored in Firestore under `chats/{rideId}/messages` and are
/// read/written in real time via [ChatService].
class ChatMessage {
  final String id;
  final String rideId;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime createdAt;
  final bool isRead;

  const ChatMessage({
    required this.id,
    required this.rideId,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.createdAt,
    this.isRead = false,
  });

  /// Build from a Firestore document snapshot.
  factory ChatMessage.fromDoc(dynamic doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final createdAt = data['createdAt'];
    DateTime parsed;
    if (createdAt is DateTime) {
      parsed = createdAt;
    } else if (createdAt != null) {
      // Firestore Timestamp
      parsed = (createdAt).toDate();
    } else {
      parsed = DateTime.now();
    }
    return ChatMessage(
      id: doc.id as String? ?? '',
      rideId: (data['rideId'] as String?) ?? '',
      senderId: (data['senderId'] as String?) ?? '',
      receiverId: (data['receiverId'] as String?) ?? '',
      text: (data['text'] as String?) ?? '',
      createdAt: parsed,
      isRead: (data['isRead'] as bool?) ?? false,
    );
  }

  /// Map for writing to Firestore.
  Map<String, dynamic> toMap(String currentUid) {
    return {
      'rideId': rideId,
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'createdAt': createdAt,
      'isRead': isRead,
    };
  }
}
