import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat-forward/forward_sheet.dart';
import '../chat_icon.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../tiptap_plain_text.dart';
import 'quick_react_sheet.dart';
import 'thread_sheet.dart';

Future<void> showMessageActions(
  BuildContext context,
  WidgetRef ref,
  ChatMessage msg, {
  required String conversationId,
  String? threadRootId,
}) async {
  if (msg.isDeleted) return;
  final isMine = msg.userId == ref.read(chatProvider).currentUserId;
  final conversation = ref.read(chatProvider).conversationById(conversationId);
  final isDm = conversation?.isDm ?? true;

  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const ChatIcon(HugeIcons.strokeRoundedSmile),
            title: const Text('React'),
            onTap: () => Navigator.pop(ctx, 'react'),
          ),
          ListTile(
            leading: const Icon(Icons.reply, size: 22),
            title: const Text('Reply'),
            onTap: () => Navigator.pop(ctx, 'reply'),
          ),
          ListTile(
            leading: const ChatIcon(HugeIcons.strokeRoundedForward01),
            title: const Text('Forward'),
            onTap: () => Navigator.pop(ctx, 'forward'),
          ),
          ListTile(
            leading: const Icon(Icons.copy_rounded, size: 22),
            title: const Text('Copy'),
            onTap: () => Navigator.pop(ctx, 'copy'),
          ),
          if (!isDm && threadRootId == null)
            ListTile(
              leading: const ChatIcon(HugeIcons.strokeRoundedComment01),
              title: const Text('Reply in thread'),
              onTap: () => Navigator.pop(ctx, 'thread'),
            ),
          if (isMine)
            ListTile(
              leading: const ChatIcon(HugeIcons.strokeRoundedEdit01),
              title: const Text('Edit'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
          if (isMine)
            ListTile(
              leading: ChatIcon(
                HugeIcons.strokeRoundedDelete02,
                color: Colors.red.shade300,
              ),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
        ],
      ),
    ),
  );
  if (!context.mounted || action == null) return;
  final n = ref.read(chatProvider.notifier);
  switch (action) {
    case 'react':
      final emoji = await showQuickReactSheet(context);
      if (emoji != null) {
        await n.toggleReaction(msg.id, emoji);
      }
    case 'reply':
      n.setReplyToMessage(msg);
    case 'forward':
      await showForwardSheet(context, ref, msg);
    case 'copy':
      await copyMessageText(context, msg);
    case 'thread':
      if (isDm) {
        n.setReplyToMessage(msg);
      } else {
        openThreadSheet(context, conversationId, msg);
      }
    case 'edit':
      final edited = await _editDialog(context, tiptapToPlainText(msg.body));
      if (edited != null) {
        await n.editMessage(msg.id, textToTiptapJson(edited));
      }
    case 'delete':
      await n.deleteMessage(msg.id);
  }
}

/// Double-tap action — copy message text straight to clipboard, no popup.
Future<void> copyMessageText(BuildContext context, ChatMessage msg) async {
  if (msg.isDeleted) return;
  await Clipboard.setData(ClipboardData(text: tiptapToPlainText(msg.body)));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Copied to clipboard'),
      duration: Duration(seconds: 2),
    ),
  );
}

Future<String?> _editDialog(BuildContext context, String initial) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Edit message'),
      content: TextField(controller: ctrl, maxLines: 4),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
