/// Who sent a support chat message.
enum SupportSender { user, support }

/// A single message in the captain ↔ support conversation.
class SupportMessage {
  final String id;
  final String text;
  final SupportSender sender;
  final DateTime timestamp;

  const SupportMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    final rawSender = json['sender'] as String? ?? 'USER';
    final sender = rawSender.toUpperCase() == 'ADMIN'
        ? SupportSender.support
        : SupportSender.user;

    return SupportMessage(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      sender: sender,
      timestamp: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}
