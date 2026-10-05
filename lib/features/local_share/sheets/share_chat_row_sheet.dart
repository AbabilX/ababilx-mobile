import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';
import '../data/share_thread_queries.dart';
import '../providers/share_in_chats.dart';
import '../share_text.dart';

/// Long press on a device thread in the chat list: the one thing that can be
/// done to it from there is to send it back to Local Share. Everything else
/// (block, forget) stays behind the thread's own menu.
Future<void> showShareChatRowSheet(
  BuildContext context,
  WidgetRef ref,
  ShareThread thread,
) async {
  final remove = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: ListTile(
        leading: const ChatIcon(HugeIcons.strokeRoundedBubbleChatCancel),
        title: Text(lsText(ref, 'ls_hide_from_chats')),
        subtitle: Text(lsText(ref, 'ls_hide_from_chats_sub')),
        onTap: () => Navigator.pop(sheet, true),
      ),
    ),
  );
  if (remove != true) return;
  await ref
      .read(shareInChatsProvider.notifier)
      .setShown(thread.device.deviceId, false);
}
