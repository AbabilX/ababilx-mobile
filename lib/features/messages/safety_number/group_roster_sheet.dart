import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/text/display_name.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../data/models/chat_models.dart';
import '../message_e2ee/group_roster_pins.dart';
import '../providers/chat_provider.dart';

/// Lists the people who can newly read a group ([memberIds]). Closing it,
/// any way, is the look that clears the notice.
Future<void> showGroupRosterSheet(
  BuildContext context, {
  required String conversationId,
  required List<String> memberIds,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) =>
        _RosterSheet(conversationId: conversationId, memberIds: memberIds),
  );
  final myId = container.read(chatProvider).currentUserId;
  await const GroupRosterPins().markSeen(myId, conversationId);
}

class _RosterSheet extends ConsumerStatefulWidget {
  const _RosterSheet({required this.conversationId, required this.memberIds});

  final String conversationId;
  final List<String> memberIds;

  @override
  ConsumerState<_RosterSheet> createState() => _RosterSheetState();
}

class _RosterSheetState extends ConsumerState<_RosterSheet> {
  // The sealing roster carries ids only; names come from the member list.
  // Under group privacy that list is short for a non-admin, and whoever is
  // missing from it reads "A member".
  late final Future<Map<String, ChatMember>> _members = ref
      .read(chatProvider.notifier)
      .listChannelMembers(widget.conversationId)
      .then((list) => {for (final m in list) m.userId: m})
      .catchError((_) => <String, ChatMember>{});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: Text(
                'New in this chat',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Your phone now encrypts new messages here for these people '
                'too. If you do not know one of them, ask a group admin.',
                style: TextStyle(color: colors.onSurfaceVariant, height: 1.35),
              ),
            ),
            Flexible(
              child: FutureBuilder<Map<String, ChatMember>>(
                future: _members,
                builder: (context, members) => ListView(
                  shrinkWrap: true,
                  children: [
                    for (final id in widget.memberIds) _row(members.data?[id]),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FilledButton(
                style: FilledButton.styleFrom(shape: const StadiumBorder()),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(ChatMember? member) {
    final name = safeDisplayName(member?.name, fallback: 'A member');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: ClipOval(
        child: AppAvatar(size: 40, url: member?.avatarUrl, name: name),
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: const Text('Can read new messages'),
    );
  }
}
