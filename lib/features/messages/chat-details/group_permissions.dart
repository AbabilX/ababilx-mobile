import '../data/models/chat_models.dart';

/// Who may do what to a group, decided the way the server decides it
/// (`services/chat/access*.go`), so nothing on the details screen offers a
/// call that answers 403.
///
/// Every group answers to its own roles and its permission set, all of which
/// travel on the conversation. Since server migration 0157 that set is
/// Telegram's: `myPermissions` is what the viewer may do (everything for an
/// admin), already combining the group's defaults with any exception an admin
/// made for them. A server older than 0157 sends no set, and the two 0109
/// switches decide the two things they always covered; everything else is
/// open, as it was.
class GroupPermissions {
  const GroupPermissions(this.conversation);

  final ChatConversation conversation;

  bool get _admin => conversation.iAmAdmin;
  bool get _group => conversation.type == 'group';

  GroupMemberPerms? get _mine => _group ? conversation.myPermissions : null;

  /// Archive, delete, roles, removal, the permission screens — admins only,
  /// and deliberately not itself a switch.
  bool get canManage => _admin;

  /// Name, description, pictures.
  bool get canEditInfo =>
      _admin || (_mine?.changeInfo ?? conversation.editInfoRole == 'member');

  bool get canAddMembers =>
      _admin || (_mine?.addUsers ?? conversation.addMembersRole == 'member');

  /// Posting anything at all: text, voice, files, thread replies, reactions.
  bool get canSend => _admin || (_mine?.sendMessages ?? true);

  bool canSendMedia(GroupMediaKind kind) =>
      _admin || (_mine?.allowsMedia(kind) ?? true);

  /// One attachment, by the type and name it would be uploaded with. A voice
  /// note needs only [canSend].
  bool canSendAttachment(String contentType, String fileName) {
    final kind = groupMediaKindFor(contentType, fileName);
    return kind == null ? canSend : canSendMedia(kind);
  }

  bool get canPinForEveryone =>
      _group && (_admin || (_mine?.pinMessages ?? false));

  bool get canStartCall => _admin || (_mine?.startCalls ?? true);

  /// Forward OUT of this group. Group privacy is a separate, group-wide
  /// refusal, checked beside this where forwarding is offered.
  bool get canForward => _admin || (_mine?.forward ?? true);

  /// Admins tag anyone; a member only themselves, while Edit Own Tag is on.
  bool canSetTag({required bool self}) =>
      _group && (_admin || (self && (_mine?.editOwnTag ?? false)));
}
