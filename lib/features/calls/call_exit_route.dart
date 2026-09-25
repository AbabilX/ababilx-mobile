import '../chat-lock/data/chat_lock_index.dart';

/// Where the app goes once a 1:1 call is over: back to that chat, unless the
/// chat is locked.
///
/// A call can end on a locked phone or in a pocket. Opening a locked chat
/// then would put its unlock prompt up for nobody — and, over the keyguard,
/// ask the phone lock for a chat while the phone itself is still locked.
String callExitRoute(
  String? conversationId,
  Map<String, ChatLockMethod> locks,
) {
  if (conversationId == null || conversationId.isEmpty) return '/messages';
  if (locks.containsKey(conversationId)) return '/messages';
  return '/messages/$conversationId';
}
