import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';

Future<void> showForwardDialog(
  BuildContext context,
  WidgetRef ref,
  ChatMessage message,
) async {
  final chat = ref.read(chatProvider);
  final targets = [...chat.channels, ...chat.dms]
      .where((c) => c.id != message.conversationId)
      .toList();
  final selected = <String>{};

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Forward message'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: targets
                .map(
                  (c) => CheckboxListTile(
                    value: selected.contains(c.id),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          selected.add(c.id);
                        } else {
                          selected.remove(c.id);
                        }
                      });
                    },
                    title: Text(c.displayTitle(chat.currentUserId)),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: selected.isEmpty
                ? null
                : () async {
                    await ref.read(chatProvider.notifier).forwardMessage(
                          messageId: message.id,
                          conversationIds: selected.toList(),
                        );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
            child: const Text('Forward'),
          ),
        ],
      ),
    ),
  );
}
