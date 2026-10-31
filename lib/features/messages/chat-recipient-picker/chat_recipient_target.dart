import 'package:equatable/equatable.dart';

import '../data/models/chat_connection.dart';
import '../data/models/chat_conversation.dart';

enum ChatRecipientKind { conversation, person }

/// A destination in the shared recipient picker.
///
/// A person id and a conversation id can both be UUIDs. The kind is therefore
/// part of equality and the selection key; otherwise a rare id collision could
/// send a share to the wrong destination.
class ChatRecipientTarget extends Equatable {
  const ChatRecipientTarget._({
    required this.kind,
    required this.id,
    required this.name,
    this.avatarUrl = '',
    this.isGroup = false,
    this.memberAvatars = const [],
    this.subtitle = '',
  });

  final ChatRecipientKind kind;
  final String id;
  final String name;

  /// The picture to draw: a person's avatar, a DM peer's, or a group's own
  /// photo. Empty means fall back — to the member montage for a group, to
  /// initials for anyone else.
  final String avatarUrl;

  /// A conversation may be a DM or a group, and they fall back differently, so
  /// the row cannot tell them apart from an empty member list alone.
  final bool isGroup;
  final List<String> memberAvatars;
  final String subtitle;

  String get selectionKey => '${kind.name}:$id';

  factory ChatRecipientTarget.conversation(
    ChatConversation conversation,
    String currentUserId,
  ) {
    return ChatRecipientTarget._(
      kind: ChatRecipientKind.conversation,
      id: conversation.id,
      name: conversation.displayTitle(currentUserId),
      avatarUrl: conversation.isGroupConversation
          ? (conversation.avatarUrl ?? '')
          : (conversation.peerUserAvatar ?? ''),
      isGroup: conversation.isGroupConversation,
      memberAvatars: conversation.memberAvatars,
      // Group member names are intentionally not present in the sidebar API.
      // Do not invent a localized count here; the row stays visually clean.
      subtitle: '',
    );
  }

  factory ChatRecipientTarget.person(ChatUserSummary person) =>
      ChatRecipientTarget._(
        kind: ChatRecipientKind.person,
        id: person.userId,
        name: person.name,
        avatarUrl: person.avatarUrl,
        subtitle: person.username.isEmpty ? '' : '@${person.username}',
      );

  @override
  List<Object?> get props => [
    kind,
    id,
    name,
    avatarUrl,
    isGroup,
    memberAvatars,
    subtitle,
  ];
}
