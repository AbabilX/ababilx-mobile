import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../messages/providers/chat_provider.dart';
import '../providers/wall_provider.dart';

Future<void> showWallForwardSheet(
  BuildContext context,
  WidgetRef ref,
  String postId,
) async {
  final chat = ref.read(chatProvider);
  final targets = [...chat.channels, ...chat.dms];
  final selected = <String>{};

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Forward to chat'),
        content: SizedBox(
          width: double.maxFinite,
          child: targets.isEmpty
              ? const Text('No conversations yet. Open Messages first.')
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final c in targets)
                      CheckboxListTile(
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
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: selected.isEmpty
                ? null
                : () async {
                    await ref.read(wallProvider.notifier).forwardPost(
                          postId: postId,
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
