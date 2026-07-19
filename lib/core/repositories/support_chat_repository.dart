import 'package:waslny_captain/core/models/support_message.dart';
import 'package:waslny_captain/core/services/api_service.dart';

/// Repository that talks to the Waslny Backend support-chat API.
///
/// Mirrors [RatingsRepository]: connection failures are rethrown (not caught)
/// so the UI can show a proper error + retry. The only empty result is when
/// the backend is intentionally disabled. No local simulation / auto-reply.
class SupportChatRepository {
  SupportChatRepository._();
  static final SupportChatRepository instance = SupportChatRepository._();

  final ApiService _api = ApiService.instance;

  /// Loads the full conversation for the current user.
  Future<List<SupportMessage>> fetchMessages() async {
    final result = await _api.getSupportMessages();

    // Support both a direct payload and a `data` envelope.
    final payload = result['data'] as Map<String, dynamic>? ?? result;

    final raw = payload['messages'];
    final List<SupportMessage> messages = [];
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map<String, dynamic>) continue;
        messages.add(SupportMessage.fromJson(item));
      }
    }
    return messages;
  }

  /// Sends a USER message and returns the saved message from the backend.
  Future<SupportMessage> sendMessage(String text) async {
    final result = await _api.sendSupportMessage(text);
    final payload = result['data'] as Map<String, dynamic>? ?? result;
    return SupportMessage.fromJson(payload);
  }
}
