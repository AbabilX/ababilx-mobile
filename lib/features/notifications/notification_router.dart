/// Resolves FCM `data.type` to an in-app route.
class NotificationRouter {
  NotificationRouter._();

  static String pathForData(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    final conversationId = data['conversation_id']?.toString();
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
          return '/messages/$conversationId';
        }
        return '/messages';
      default:
        return '/messages';
    }
  }
}
