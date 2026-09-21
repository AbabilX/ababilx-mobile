import '../../../shared/text/name_search.dart';
import '../data/models/chat_models.dart';
import 'composer_mention_picker.dart';

/// Who the `@` popover offers, in order.
///
/// - A DM offers the other person and nobody else: mentioning a third person
///   in a two-person chat notifies nobody who can read it.
/// - A group offers its members first, then the caller's accepted connections
///   who are NOT in it, marked `isInChannel: false` so the picker draws them
///   under the "Outsiders" line. Accepted connections only, because that is
///   who the server lets you add (`CanInviteToGroup`), and the send path
///   offers to add a mentioned outsider.
/// - Outsiders wait for the member list: before it loads every member would
///   look like an outsider.
/// - A group opens with an `@all` row (members only, never a feed).
/// - A webhook feed or Note to Self offers members only / nobody.
List<MentionCandidate> buildMentionCandidates({
  required ChatConversation? conversation,
  required String currentUserId,
  required List<MentionCandidate> members,
  required bool membersLoaded,
  required List<ChatUserSummary> connections,
  required String query,
}) {
  bool matches(String name) => matchesNameQuery(query, [name]);

  if (conversation == null || conversation.isDm) {
    final peerId = conversation?.peerUserId ?? '';
    final peerName = conversation?.peerUserName ?? '';
    if (conversation == null ||
        !conversation.hasDmPeer ||
        peerId == currentUserId ||
        peerName.isEmpty ||
        !matches(peerName)) {
      return const [];
    }
    return [
      MentionCandidate(
        userId: peerId,
        displayName: peerName,
        avatarUrl: conversation.peerUserAvatar,
      ),
    ];
  }

  final inGroup = <String>{};
  final out = <MentionCandidate>[
    // WhatsApp's first row. Only once there is somebody besides the caller.
    if (!conversation.isWebhook &&
        members.any((m) => m.userId.isNotEmpty && m.userId != currentUserId) &&
        matches('all'))
      MentionCandidate.all,
  ];
  for (final m in members) {
    if (m.userId.isEmpty || m.userId == currentUserId) continue;
    if (!inGroup.add(m.userId)) continue;
    if (matches(m.displayName)) out.add(m);
  }

  if (!membersLoaded || conversation.isWebhook) return out;

  for (final user in connections) {
    if (user.userId.isEmpty || user.userId == currentUserId) continue;
    if (!inGroup.add(user.userId)) continue;
    if (!matches(user.name)) continue;
    out.add(
      MentionCandidate(
        userId: user.userId,
        displayName: user.name,
        avatarUrl: user.avatarUrl.isEmpty ? null : user.avatarUrl,
        isInChannel: false,
      ),
    );
  }
  return out;
}
