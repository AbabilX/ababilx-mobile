import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../khaam/data/khaam_payload.dart';
import '../../../shared/widgets/app_toast.dart';
import '../chat-forward/forward_sheet.dart';
import '../chat-select/message_selection.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../chat-details/group_permissions.dart';
import '../group-pins/group_pin_actions.dart';
import '../group-pins/group_pins_provider.dart';
import '../providers/pinned_message_provider.dart';
import '../tiptap_plain_text.dart';
import 'delete_message_dialog.dart';
import 'edit_message_sheet.dart';
import 'pinned_message_actions.dart';
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
  // The menu is a route, and closing a route hands focus back to whatever
  // held it — the composer keeps focus after the keyboard is swiped away, so
  // Pin, Copy or Save brought the keyboard back up. When the keyboard is down
  // nobody is typing: drop the focus first. Reply and Edit still ask for it.
  if (View.of(context).viewInsets.bottom == 0) {
    FocusManager.instance.primaryFocus?.unfocus();
  }
  final isMine = msg.userId == ref.read(chatProvider).currentUserId;
  final conversation = ref.read(chatProvider).conversationById(conversationId);
  final isDm = conversation?.isDm ?? true;
  // A private group (server 0154) keeps everything inside it: no Save, no
  // Forward — for the sender too. The server refuses the forward as well.
  final locked = conversation?.groupPrivacy ?? false;
  // A Khaam is a card: a forwarded copy would share its id (and its opened
  // state), editing would overwrite it, and its body is a payload, not text.
  final isKhaam = KhaamPayload.tryParse(msg.body) != null;
  final pinned = ref
      .read(pinnedMessageIdsProvider(conversationId))
      .contains(msg.id);
  // Member permissions (server 0157). A read-only member cannot reply, react
  // or edit; one barred from forwarding forwards nothing out of the group.
  final perms = conversation == null ? null : GroupPermissions(conversation);
  final canSend = perms?.canSend ?? true;
  final canForward = perms?.canForward ?? true;
  // Group pins are offered only to whoever may set them; everyone else's
  // Pin row keeps meaning "for me".
  final canPinGroup = perms?.canPinForEveryone ?? false;
  final groupPinned =
      canPinGroup &&
      ref.read(groupPinnedIdsProvider(conversationId)).contains(msg.id);

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
    showSave: !isKhaam && !locked && canSaveMessageAttachments(msg),
    // Selection has a top bar and an action bar of its own, and a thread
    // panel has room for neither — so the door only opens on the main
    // timeline, where those bars replace the header and the composer.
    showSelect: threadRootId == null,
    showPin: threadRootId == null && !msg.isPending && !msg.contentPurged,
    pinned: pinned || groupPinned,
    // The sender's own restricted photo is still theirs to forward; nobody
    // else may (the server refuses it too).
    showForward:
        !isKhaam && !locked && canForward && (isMine || !msg.hasProtectedMedia),
    showCopy: !isKhaam,
    showEdit: !isKhaam && canSend,
    showReply: canSend,
    showReactions: canSend,
    labels: {
      'dismiss': tr('chat_dismiss_message_actions'),
      'reply': tr('chat_reply'),
      'forward': tr('chat_forward'),
      'save': tr('chat_save_to_phone'),
      'copy': tr('chat_copy'),
      'thread': tr('chat_reply_thread'),
      'select': tr('chat_select'),
      'edit': tr('chat_edit'),
      'delete': tr('chat_delete'),
      'pin': tr('chat_pin_message'),
      'unpin': tr('chat_unpin_message'),
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
      // A feed's own composer is locked, so a quote would go nowhere: the
      // reply to a delivered message is its thread.
      if (conversation?.isWebhook == true && threadRootId == null) {
        openThreadSheet(context, conversationId, msg);
      } else {
        n.setReplyToMessage(msg);
      }
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
    case SignalMessageAction.select:
      ref
          .read(messageSelectionProvider.notifier)
          .start(conversationId: conversationId, messageId: msg.id);
    case SignalMessageAction.edit:
      await editMessageFlow(context, ref, msg);
    case SignalMessageAction.pin when canPinGroup:
      await chooseGroupPin(
        context,
        ref,
        conversationId: conversationId,
        messageId: msg.id,
        pinnedForMe: pinned,
        pinnedForEveryone: groupPinned,
      );
    case SignalMessageAction.pin:
      await setMessagePinned(
        context,
        ref,
        conversationId,
        msg.id,
        pinned: !pinned,
      );
    case SignalMessageAction.delete:
      final scope = await showDeleteMessageDialog(
        context,
        ref,
        count: 1,
        canDeleteForEveryone: isMine && !msg.isPending,
      );
      if (scope == null) return;
      try {
        scope == MessageDeleteScope.everyone
            ? await n.deleteMessage(msg.id)
            : await n.hideMessage(msg.id);
        if (pinned) ref.invalidate(pinnedMessagesProvider(conversationId));
      } catch (_) {
        if (context.mounted) {
          showAppToast(
            context,
            tr('chat_delete_selected_failed'),
            isError: true,
          );
        }
      }
  }
}

/// The edit dialog and the send behind it, shared by the long-press menu and
/// the selection bar.
Future<void> editMessageFlow(
  BuildContext context,
  WidgetRef ref,
  ChatMessage msg,
) async {
  final edited = await showEditMessageSheet(
    context,
    ref,
    tiptapToPlainText(msg.body),
  );
  if (edited == null) return;
  try {
    await ref
        .read(chatProvider.notifier)
        .editMessage(msg.id, textToTiptapJson(edited));
  } catch (error) {
    // A refused edit used to reach nobody: the exception died in the gesture
    // handler and the message simply stayed as it was, which reads as a
    // broken button.
    if (context.mounted) {
      showAppToast(context, _editFailureMessage(error), isError: true);
    }
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
