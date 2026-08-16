import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calls/providers/in_call_presence_provider.dart';
import '../../calls/widgets/in_call_label.dart';
import '../../profile/providers/user_status_provider.dart';
import '../../profile/widgets/user_status_badge.dart';
import '../chat-timeline/user_profile_sheet.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../providers/team_gate_provider.dart';

Future<void> showGroupDetailsDialog(
  BuildContext context,
  WidgetRef ref,
  ChatConversation conversation,
) async {
  final nameCtrl = TextEditingController(text: conversation.name ?? '');
  List<ChatMember> members = [];
  try {
    members = await ref
        .read(chatProvider.notifier)
        .listChannelMembers(conversation.id);
  } catch (_) {}

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: StatefulBuilder(
        builder: (ctx, setState) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (_, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.all(16),
            children: [
              Text('Group details', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Group name'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  await ref
                      .read(chatProvider.notifier)
                      .renameChannel(conversation.id, name);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save name'),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Mute notifications'),
                value: conversation.muted,
                onChanged: (v) async {
                  await ref
                      .read(chatProvider.notifier)
                      .muteConversation(conversation.id, v);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
              const Divider(),
              Text('Members', style: Theme.of(ctx).textTheme.titleSmall),
              ...members.map(
                (m) => Consumer(
                  builder: (context, ref, _) {
                    final inCall = ref.watch(isUserInCallProvider(m.userId));
                    final status = ref.watch(userStatusForProvider(m.userId));
                    final subtitle = inCall
                        ? const InCallLabel(compact: true)
                        : status != null
                        ? UserStatusBadge(status: status, compact: true)
                        : null;
                    return ListTile(
                      dense: true,
                      title: Text(m.name),
                      subtitle: subtitle,
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        showUserProfileSheet(
                          context: context,
                          ref: ref,
                          userId: m.userId,
                          userName: m.name,
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text('Add member', style: Theme.of(ctx).textTheme.titleSmall),
              ...ref.watch(teamMembersProvider).map((tm) {
                if (members.any((m) => m.userId == tm.userId)) {
                  return const SizedBox.shrink();
                }
                return ListTile(
                  dense: true,
                  title: Text(tm.displayName),
                  trailing: IconButton(
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    onPressed: () async {
                      await ref
                          .read(chatProvider.notifier)
                          .addChannelMember(conversation.id, tm.userId);
                      final updated = await ref
                          .read(chatProvider.notifier)
                          .listChannelMembers(conversation.id);
                      setState(() => members = updated);
                    },
                  ),
                );
              }),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  await ref
                      .read(chatProvider.notifier)
                      .leaveChannel(conversation.id);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  }
                },
                child: const Text('Leave group'),
              ),
              TextButton(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: ctx,
                    builder: (d) => AlertDialog(
                      title: const Text('Delete group?'),
                      content: const Text(
                        'Are you sure you want to delete this group? All messages, attachments, and members will be removed automatically from this group. This action cannot be undone.',
                        style: TextStyle(fontSize: 14, height: 1.4),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(d, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          onPressed: () => Navigator.pop(d, true),
                          child: const Text('Delete group'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await ref
                        .read(chatProvider.notifier)
                        .deleteChannel(conversation.id);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                    }
                  }
                },
                child: const Text(
                  'Delete group',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
