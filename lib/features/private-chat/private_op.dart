import '../messages/data/models/chat_message.dart';
import '../messages/data/models/chat_reaction.dart';

/// An edit, reaction or delete-for-everyone aimed at a private-chat message
/// (server 0160). The target may already be gone from the server, so an op
/// travels on its own and each phone applies it to its own copy.
class PrivateOp {
  const PrivateOp({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.kind,
    required this.targetMessageId,
    this.emoji = '',
    this.reacted = false,
    this.encryptedBody = '',
    this.encryptionNonce = '',
    this.encryptionKeyVersion = 0,
    this.createdAt = '',
  });

  static const edit = 'edit';
  static const reaction = 'reaction';
  static const delete = 'delete';

  final String id;
  final String conversationId;
  final String senderId;
  final String kind;
  final String targetMessageId;
  final String emoji;
  final bool reacted;
  final String encryptedBody;
  final String encryptionNonce;
  final int encryptionKeyVersion;
  final String createdAt;

  factory PrivateOp.fromJson(Map<String, dynamic> json) => PrivateOp(
    id: json['id'] as String? ?? '',
    conversationId: json['conversation_id'] as String? ?? '',
    senderId: json['sender_id'] as String? ?? '',
    kind: json['kind'] as String? ?? '',
    targetMessageId: json['target_message_id'] as String? ?? '',
    emoji: json['emoji'] as String? ?? '',
    reacted: json['reacted'] == true,
    encryptedBody: json['encrypted_body'] as String? ?? '',
    encryptionNonce: json['encryption_nonce'] as String? ?? '',
    encryptionKeyVersion:
        (json['encryption_key_version'] as num?)?.toInt() ?? 0,
    createdAt: json['created_at'] as String? ?? '',
  );
}

/// What applying [op] to [target] should do. The server could not check
/// authorship once the target was purged, so this phone does: only the
/// author edits or deletes, anyone in the chat reacts, and nothing crosses
/// conversations.
enum PrivateOpEffect { ignore, edit, delete, react }

PrivateOpEffect privateOpEffect(PrivateOp op, ChatMessage target) {
  if (target.conversationId != op.conversationId || target.isDeleted) {
    return PrivateOpEffect.ignore;
  }
  switch (op.kind) {
    case PrivateOp.reaction:
      return op.emoji.isEmpty ? PrivateOpEffect.ignore : PrivateOpEffect.react;
    case PrivateOp.edit:
      if (target.userId != op.senderId || op.encryptedBody.isEmpty) {
        return PrivateOpEffect.ignore;
      }
      // Edits reach a phone by two roads — live over the socket, and the
      // pull of what it missed offline — so an older one can land after a
      // newer one. The newest text wins, like the server's own row.
      return _olderThanShown(op.createdAt, target.editedAt)
          ? PrivateOpEffect.ignore
          : PrivateOpEffect.edit;
    case PrivateOp.delete:
      return target.userId == op.senderId
          ? PrivateOpEffect.delete
          : PrivateOpEffect.ignore;
  }
  return PrivateOpEffect.ignore;
}

bool _olderThanShown(String opAt, String? editedAt) {
  final op = DateTime.tryParse(opAt);
  final shown = DateTime.tryParse(editedAt ?? '');
  return op != null && shown != null && op.isBefore(shown);
}

/// [reactions] with [userId]'s [emoji] set or cleared. Idempotent: an op
/// replayed by a second pull changes nothing.
List<ChatReactionGroup> applyPrivateReaction(
  List<ChatReactionGroup> reactions, {
  required String userId,
  required String currentUserId,
  required String emoji,
  required bool reacted,
  String? userName,
}) {
  final out = <ChatReactionGroup>[];
  var found = false;
  for (final group in reactions) {
    if (group.emoji != emoji) {
      out.add(group);
      continue;
    }
    found = true;
    final users = group.users.where((u) => u.userId != userId).toList();
    if (reacted) users.add(ChatReactionUser(userId: userId, name: userName));
    if (users.isEmpty) continue;
    out.add(
      ChatReactionGroup(
        emoji: emoji,
        count: users.length,
        users: users,
        reactedByMe: users.any((u) => u.userId == currentUserId),
      ),
    );
  }
  if (!found && reacted) {
    out.add(
      ChatReactionGroup(
        emoji: emoji,
        count: 1,
        users: [ChatReactionUser(userId: userId, name: userName)],
        reactedByMe: userId == currentUserId,
      ),
    );
  }
  return out;
}
