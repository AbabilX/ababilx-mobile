/// Resolves FCM `data.type` to an in-app route.
class NotificationRouter {
  NotificationRouter._();

  static String pathForData(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    final conversationId = data['conversation_id']?.toString();
    final messageId = data['message_id']?.toString();
    switch (type) {
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
      case 'group_call':
        // Call screens are state-driven by CallStoreSync/GroupCallSync after
        // the provider verifies that the call is still live. A notification
        // route must never open a stale call screen after login/cold start.
        if (conversationId != null && conversationId.isNotEmpty) {
          return '/messages/$conversationId';
        }
        return '/messages';
      default:
        if (conversationId != null && conversationId.isNotEmpty) {
          return '/messages/$conversationId';
        }
        return '/messages';
    }
  }
}
