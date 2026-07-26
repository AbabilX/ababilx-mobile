/// Resolves FCM `data.type` to an in-app route.
class NotificationRouter {
  NotificationRouter._();

  static String pathForData(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    final conversationId = data['conversation_id']?.toString();
    final messageId = data['message_id']?.toString();
    switch (type) {
      case 'pre_send_review':
        return '/profile';
      case 'ai_assistant':
        return '/messages';
      case 'team_member_left':
        return '/profile';
      case 'chat_dm':
      case 'chat_mention':
      case 'chat_message':
        if (conversationId != null && conversationId.isNotEmpty) {
          // Open that exact chat; message_id kept for future scroll-to-message.
          if (messageId != null && messageId.isNotEmpty) {
            return '/messages/$conversationId?m=$messageId';
          }
          return '/messages/$conversationId';
        }
        return '/messages';
      case 'voice_call':
        return '/call';
      default:
        if (conversationId != null && conversationId.isNotEmpty) {
          return '/messages/$conversationId';
        }
        return '/messages';
    }
  }
}
