/// Resolves FCM `data.type` to an in-app route.
class NotificationRouter {
  NotificationRouter._();

  static String pathForData(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    final conversationId = data['conversation_id']?.toString();
    final messageId = data['message_id']?.toString();
    final boardId = data['board_id']?.toString();
    final taskId = data['task_id']?.toString();
    final postId = data['post_id']?.toString();
    switch (type) {
      case 'wall_mention':
      case 'wall_comment':
      case 'wall_reply':
        if (postId == null || postId.isEmpty) return '/wall';
        return '/wall/post/$postId';
      case 'wall_category_request':
        // Category approval lives on web only; land on the wall tab.
        return '/wall';
      case 'kanban_assignment':
      case 'kanban_mention':
      case 'kanban_comment':
      case 'kanban_watcher':
      case 'board_notes':
      case 'board_notes_mention':
        if (boardId == null || boardId.isEmpty) return '/board';
        if (taskId != null && taskId.isNotEmpty) {
          return '/board/$boardId/tasks/$taskId';
        }
        return '/board/$boardId';
      case 'pre_send_review':
        return '/settings';
      case 'ai_assistant':
        // Proactive nudges carry the ids of whatever they are nudging about.
        // Open that item directly; fall back to the AI chat when the nudge is
        // not about one specific thing (e.g. the morning briefing).
        if (boardId != null && boardId.isNotEmpty) {
          if (taskId != null && taskId.isNotEmpty) {
            return '/board/$boardId/tasks/$taskId';
          }
          return '/board/$boardId';
        }
        if (postId != null && postId.isNotEmpty) return '/wall/post/$postId';
        if (conversationId != null && conversationId.isNotEmpty) {
          return '/messages/$conversationId';
        }
        return '/messages';
      case 'team_member_left':
        return '/settings';
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
