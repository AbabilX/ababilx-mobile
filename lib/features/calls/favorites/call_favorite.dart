import '../../messages/data/models/chat_conversation.dart';
import '../data/models/call_log_entry.dart';

/// One person pinned to the top of the Talks tab for a one-tap call.
///
/// Holds its own name and picture, so the strip draws offline and before the
/// chat list has loaded. The live conversation, when the phone has it, wins
/// for both (a nickname, a new photo) — this copy is only the fallback.
class CallFavorite {
  const CallFavorite({
    required this.conversationId,
    required this.peerUserId,
    required this.name,
    this.avatarUrl,
  });

  final String conversationId;
  final String peerUserId;
  final String name;
  final String? avatarUrl;

  factory CallFavorite.fromConversation(
    ChatConversation conversation,
    String name,
  ) => CallFavorite(
    conversationId: conversation.id,
    peerUserId: conversation.peerUserId ?? '',
    name: name,
    avatarUrl: conversation.peerUserAvatar,
  );

  factory CallFavorite.fromEntry(CallLogEntry entry) => CallFavorite(
    conversationId: entry.conversationId,
    peerUserId: entry.peerUserId,
    name: entry.title,
    avatarUrl: entry.avatarUrl,
  );

  Map<String, dynamic> toJson() => {
    'c': conversationId,
    'u': peerUserId,
    'n': name,
    if (avatarUrl != null) 'a': avatarUrl,
  };

  /// Null for anything unreadable, so one bad entry never empties the list.
  static CallFavorite? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['c'];
    if (id is! String || id.isEmpty) return null;
    return CallFavorite(
      conversationId: id,
      peerUserId: json['u'] as String? ?? '',
      name: json['n'] as String? ?? '',
      avatarUrl: json['a'] as String?,
    );
  }
}
