import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat_connection.dart';
import '../data/models/chat_conversation.dart';
import '../providers/chat_provider.dart';
import '../providers/messageable_people_provider.dart';
import '../providers/team_gate_provider.dart';

class GroupMemberPicker extends ConsumerWidget {
  const GroupMemberPicker({
    super.key,
    required this.conversation,
    required this.memberIds,
    required this.onAdded,
  });

  final ChatConversation conversation;
  final Set<String> memberIds;
  final VoidCallback onAdded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidates = conversation.isPersonal
        ? ref.watch(messageablePeopleProvider)
        : ref
              .watch(teamMembersProvider)
              .map(
                (member) => ChatUserSummary(
                  userId: member.userId,
                  name: member.displayName,
                  avatarUrl: member.avatarUrl ?? '',
                  sharedWorkspace: true,
                  canMessage: true,
                ),
              )
              .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: candidates
          .where((user) => !memberIds.contains(user.userId))
          .map(
            (user) => ListTile(
              dense: true,
              title: Text(user.name),
              trailing: IconButton(
                icon: const Icon(Icons.person_add_alt_1_outlined),
                onPressed: () async {
                  await ref
                      .read(chatProvider.notifier)
                      .addChannelMember(conversation.id, user.userId);
                  onAdded();
                },
              ),
            ),
          )
          .toList(),
    );
  }
}
