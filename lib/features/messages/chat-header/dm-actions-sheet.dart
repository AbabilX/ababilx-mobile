import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';

Future<void> showDmActionsSheet(
  BuildContext context,
  WidgetRef ref,
  ChatConversation conversation,
) async {
  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.notifications_off_outlined),
            title: Text(conversation.muted ? 'Unmute' : 'Mute'),
            onTap: () async {
              await ref
                  .read(chatProvider.notifier)
                  .muteConversation(conversation.id, !conversation.muted);
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
          if (conversation.peerUserName != null)
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(conversation.peerUserName!),
              subtitle: conversation.peerLeft ? const Text('Left conversation') : null,
            ),
        ],
      ),
    ),
  );
}
