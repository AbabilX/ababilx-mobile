import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';

Future<ChatConversation?> showCreateChannelDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final nameCtrl = TextEditingController();
  var isPrivate = false;
  return showDialog<ChatConversation>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Create group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Group name'),
              autofocus: true,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Private group'),
              value: isPrivate,
              onChanged: (v) => setState(() => isPrivate = v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final channel = await ref
                  .read(chatProvider.notifier)
                  .createChannel(name: name, isPrivate: isPrivate);
              if (ctx.mounted) Navigator.pop(ctx, channel);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    ),
  );
}
