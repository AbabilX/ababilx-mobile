import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../providers/team_gate_provider.dart';

/// Who may do what to a group, decided the way the server decides it
/// (`services/chat/access*.go`), so nothing on the details screen offers a
/// call that answers 403.
///
/// A personal group answers to its roles and its two switches, all of which
/// travel on the conversation. A workspace channel or feed answers to the
/// team: its creator, a member whose row says admin, or the team leader — and
/// two of those live outside the conversation, which is why this is not a
/// getter on [ChatConversation]. The old `!isPersonal || …` getters showed
/// every workspace member the pencil and let the server say no.
class GroupPermissions {
  const GroupPermissions({
    required this.conversation,
    required this.currentUserId,
    required this.isTeamLeader,
  });

  /// For a build method: re-renders when the team role or the user changes.
  static GroupPermissions of(WidgetRef ref, ChatConversation conversation) =>
      GroupPermissions(
        conversation: conversation,
        currentUserId: ref.watch(chatProvider.select((s) => s.currentUserId)),
        isTeamLeader: ref.watch(_teamLeaderProvider),
      );

  /// For a callback (a sheet, a tap), where watching would be a mistake.
  static GroupPermissions read(WidgetRef ref, ChatConversation conversation) =>
      GroupPermissions(
        conversation: conversation,
        currentUserId: ref.read(chatProvider).currentUserId,
        isTeamLeader: ref.read(_teamLeaderProvider),
      );

  final ChatConversation conversation;
  final String currentUserId;
  final bool isTeamLeader;

  bool get _admin => conversation.iAmAdmin;

  /// `CanManageConversation` for a workspace conversation: creator, admin
  /// row, or team leader.
  bool get _managesWorkspace =>
      _admin ||
      isTeamLeader ||
      (currentUserId.isNotEmpty && conversation.createdBy == currentUserId);

  /// Archive, delete, roles, removal — admins only in a personal group, and
  /// deliberately not itself a switch.
  bool get canManage => conversation.isPersonal ? _admin : _managesWorkspace;

  /// Name, description, pictures. The group's own switch can widen this past
  /// admins in a personal group; a workspace channel has no such switch.
  bool get canEditInfo => conversation.isPersonal
      ? _admin || conversation.editInfoRole == 'member'
      : _managesWorkspace;

  bool get canAddMembers => conversation.isPersonal
      ? _admin || conversation.addMembersRole == 'member'
      : _managesWorkspace;
}

final _teamLeaderProvider = Provider<bool>((ref) {
  final team = ref.watch(teamGateProvider);
  return team.maybeWhen(data: (d) => d?.isLeader ?? false, orElse: () => false);
});
