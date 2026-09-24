import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat_models.dart';

/// Live member tags per group (server 0157): conversation id → user id → tag.
///
/// A fetched message carries its author's tag as the server read it
/// (`sender_tag`), and a stored message keeps that forever — so a tag changed
/// or cleared since then would never reach the rows already on the phone.
/// This map is what does: the roster and every `chat.member.updated` write
/// here, and a bubble asks here first. An empty string is a real answer
/// ("cleared"), distinct from "not known yet".
class GroupMemberTags extends Notifier<Map<String, Map<String, String>>> {
  @override
  Map<String, Map<String, String>> build() => const {};

  void setTag(String conversationId, String userId, String tag) {
    if (conversationId.isEmpty || userId.isEmpty) return;
    final current = state[conversationId] ?? const <String, String>{};
    if (current[userId] == tag) return;
    state = {
      ...state,
      conversationId: {...current, userId: tag},
    };
  }

  /// The roster is the whole truth for everyone on it.
  void seedFromRoster(String conversationId, List<ChatMember> members) {
    if (conversationId.isEmpty || members.isEmpty) return;
    state = {
      ...state,
      conversationId: {
        ...?state[conversationId],
        for (final m in members) m.userId: m.tag,
      },
    };
  }
}

final groupMemberTagsProvider =
    NotifierProvider<GroupMemberTags, Map<String, Map<String, String>>>(
      GroupMemberTags.new,
    );

/// Bumped when an admin-controlled fact about a member changed
/// (`chat.member.updated`): a roster on screen reloads on it.
final groupRosterRevisionProvider = StateProvider.family<int, String>(
  (ref, conversationId) => 0,
);
