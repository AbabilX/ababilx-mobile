import '../data/models/chat_models.dart';

/// Who may do what to a group, decided the way the server decides it
/// (`services/chat/access*.go`), so nothing on the details screen offers a
/// call that answers 403.
///
/// Every group answers to its own roles and its two switches, all of which
/// travel on the conversation — a converted workspace channel included. A team
/// role used to count here (the leader managed every channel) and no longer
/// counts anywhere: since the server's migration 0145 nothing about a workspace
/// reaches into a conversation, so who leads which team can neither widen nor
/// narrow what anyone may do in a group.
class GroupPermissions {
  const GroupPermissions(this.conversation);

  final ChatConversation conversation;

  bool get _admin => conversation.iAmAdmin;

  /// Archive, delete, roles, removal — admins only, and deliberately not
  /// itself a switch.
  bool get canManage => _admin;

  /// Name, description, pictures. The group's own switch can widen this past
  /// admins.
  bool get canEditInfo => _admin || conversation.editInfoRole == 'member';

  bool get canAddMembers => _admin || conversation.addMembersRole == 'member';
}
