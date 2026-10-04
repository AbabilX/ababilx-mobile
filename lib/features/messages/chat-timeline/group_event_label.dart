import '../data/models/chat_message.dart';

/// "You added Alice" / "Bob changed the group photo" — built on the device
/// because only this side knows who is reading. The server's [ChatMessage.body]
/// is the third-person fallback for events this build does not recognise.
///
/// Mirrors web `chat-timeline/group-event-row.tsx`.
String groupEventLabel(ChatMessage message, String currentUserId) {
  final meta = message.meta;
  final event = meta?['event'];
  if (event is! String || event.isEmpty) return message.body;

  final actorId = meta?['actor_id'] as String? ?? '';
  final targetId = meta?['target_id'] as String? ?? '';
  final actor = actorId == currentUserId
      ? 'You'
      : _displayName(meta?['actor_name'] as String?);
  final target = targetId == currentUserId
      ? 'you'
      : _displayName(meta?['target_name'] as String?);
  final value = meta?['value'] as String? ?? '';

  switch (event) {
    case 'group_created':
      return '$actor created the group';
    case 'name_changed':
      return '$actor changed the group name to "$value"';
    case 'description_changed':
      return value.isEmpty
          ? '$actor removed the group description'
          : '$actor changed the group description';
    case 'avatar_changed':
      return value.isEmpty
          ? '$actor removed the group photo'
          : '$actor changed the group photo';
    case 'banner_changed':
      return value.isEmpty
          ? '$actor removed the group banner'
          : '$actor changed the group banner';
    case 'member_added':
      return '$actor added $target';
    case 'member_removed':
      return '$actor removed $target';
    case 'member_left':
      return '$actor left the group';
    case 'member_joined_link':
      return '$actor joined using the group link';
    case 'role_changed':
      // Never "You made you an admin": the server refuses a self role change.
      return value == 'admin'
          ? '$actor made $target an admin'
          : '$actor removed $target as an admin';
    case 'permissions_changed':
      return '$actor changed the group permissions';
    case 'message_pinned':
      return '$actor pinned a message';
    case 'privacy_changed':
      return value == 'on'
          ? '$actor turned on group privacy'
          : '$actor turned off group privacy';
    // A DM's line, not a group's (server 0160) — rendered by the same row.
    case 'private_chat_changed':
      return value == 'on'
          ? '$actor turned on private chat'
          : '$actor turned off private chat';
    default:
      return message.body;
  }
}

String _displayName(String? raw) {
  final trimmed = raw?.trim() ?? '';
  return trimmed.isEmpty ? 'Someone' : trimmed;
}
