import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../chat-forward/forward_sheet.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../tiptap_plain_text.dart';
import 'reaction_emoji_picker.dart';
import 'save_message_attachments.dart';
import 'signal_menu_pointer.dart';
import 'signal_message_menu.dart';
import 'thread_sheet.dart';

Future<void> showMessageActions(
  BuildContext context,
  WidgetRef ref,
  ChatMessage msg, {
  required String conversationId,
  String? threadRootId,
  Rect? anchor,
  Widget? focused,
  SignalMenuPointer? pointer,
}) async {
  if (msg.isDeleted) return;
  final isMine = msg.userId == ref.read(chatProvider).currentUserId;
  final conversation = ref.read(chatProvider).conversationById(conversationId);
  final isDm = conversation?.isDm ?? true;

  String tr(String key) => AppTranslations.translate(context, ref, key);
  final result = await showSignalMessageMenu(
    context: context,
    anchor:
        anchor ??
        Rect.fromLTWH(
          16,
          MediaQuery.sizeOf(context).height * 0.28,
          MediaQuery.sizeOf(context).width - 32,
          1,
        ),
    focused: focused ?? const SizedBox.shrink(),
    pointer: pointer,
    isMine: isMine,
    showThread: !isDm && threadRootId == null,
    showSave: canSaveMessageAttachments(msg),
    labels: {
      'dismiss': tr('chat_dismiss_message_actions'),
      'reply': tr('chat_reply'),
      'forward': tr('chat_forward'),
      'save': tr('chat_save_to_phone'),
      'copy': tr('chat_copy'),
      'thread': tr('chat_reply_thread'),
      'edit': tr('chat_edit'),
      'delete': tr('chat_delete'),
      'moreReactions': tr('chat_more_reactions'),
    },
  );
  if (!context.mounted || result == null) return;
  final n = ref.read(chatProvider.notifier);
  if (result case SignalMessageReaction(:final emoji)) {
    final selected = emoji.isEmpty
        ? await showReactionEmojiPicker(context)
        : emoji;
    if (selected != null) await n.toggleReaction(msg.id, selected);
    return;
  }
  final action = (result as SignalMessageCommand).action;
  switch (action) {
    case SignalMessageAction.reply:
      n.setReplyToMessage(msg);
    case SignalMessageAction.forward:
      await showForwardSheet(context, ref, msg);
    case SignalMessageAction.save:
      await saveMessageAttachments(context, ref, msg);
    case SignalMessageAction.copy:
      await copyMessageText(context, ref, msg);
    case SignalMessageAction.thread:
      if (isDm) {
        n.setReplyToMessage(msg);
      } else {
        openThreadSheet(context, conversationId, msg);
      }
    case SignalMessageAction.edit:
      final edited = await _editDialog(
        context,
        ref,
        tiptapToPlainText(msg.body),
      );
      if (edited != null) {
        try {
          await n.editMessage(msg.id, textToTiptapJson(edited));
        } catch (error) {
          // A refused edit used to reach nobody: the exception died in the
          // gesture handler and the message simply stayed as it was, which
          // reads as a broken button.
          if (context.mounted) {
            showAppToast(context, _editFailureMessage(error), isError: true);
          }
        }
      }
    case SignalMessageAction.delete:
      await n.deleteMessage(msg.id);
  }
}

/// The server's own words where it has any, so a refusal is diagnosable
/// instead of "could not edit".
String _editFailureMessage(Object error) {
  final detail = error is DioException
      ? (error.response?.data is Map
                ? (error.response?.data as Map)['error']?.toString()
                : null) ??
            error.message
      : error.toString();
  final trimmed = detail?.trim() ?? '';
  return trimmed.isEmpty ? 'Could not edit this message' : trimmed;
}

/// Double-tap action — copy message text straight to clipboard, no popup.
Future<void> copyMessageText(
  BuildContext context,
  WidgetRef ref,
  ChatMessage msg,
) async {
  if (msg.isDeleted) return;
  await Clipboard.setData(ClipboardData(text: tiptapToPlainText(msg.body)));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        AppTranslations.translate(context, ref, 'chat_copied_clipboard'),
      ),
      duration: const Duration(seconds: 2),
    ),
  );
}

Future<String?> _editDialog(
  BuildContext context,
  WidgetRef ref,
  String initial,
) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(AppTranslations.translate(context, ref, 'chat_edit_message')),
      content: TextField(controller: ctrl, maxLines: 4),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(AppTranslations.translate(context, ref, 'cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: Text(AppTranslations.translate(context, ref, 'chat_save')),
        ),
      ],
    ),
  );
}
