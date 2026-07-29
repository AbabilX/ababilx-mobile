import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../providers/team_gate_provider.dart';

import '../chat-timeline/user_profile_sheet.dart';

Future<void> showGroupDetailsDialog(
  BuildContext context,
  WidgetRef ref,
  ChatConversation conversation,
) async {
  final nameCtrl = TextEditingController(text: conversation.name ?? '');
  List<ChatMember> members = [];
  try {
    members = await ref.read(chatProvider.notifier).listChannelMembers(conversation.id);
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
              Text('Channel details',
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Channel name'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  await ref.read(chatProvider.notifier).renameChannel(conversation.id, name);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save name'),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Mute notifications'),
                value: conversation.muted,
                onChanged: (v) async {
                  await ref.read(chatProvider.notifier).muteConversation(conversation.id, v);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
              const Divider(),
              Text('Members', style: Theme.of(ctx).textTheme.titleSmall),
              ...members.map((m) => ListTile(
                    dense: true,
                    title: Text(m.name),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                    onTap: () {
                      Navigator.pop(ctx);
                      showUserProfileSheet(
                        context: context,
                        ref: ref,
                        userId: m.userId,
                        userName: m.name,
                      );
                    },
                  )),
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
                  await ref.read(chatProvider.notifier).leaveChannel(conversation.id);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  }
                },
                child: const Text('Leave channel'),
              ),
              TextButton(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: ctx,
                    builder: (d) => AlertDialog(
                      title: const Text('Delete channel?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Delete')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await ref.read(chatProvider.notifier).deleteChannel(conversation.id);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                    }
                  }
                },
                child: const Text('Delete channel', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
