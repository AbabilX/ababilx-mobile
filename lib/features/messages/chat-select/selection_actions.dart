import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../chat-details/group_permissions.dart';
import '../chat-forward/forward_sheet.dart';
import '../chat-timeline/delete_message_dialog.dart';
import '../chat-timeline/message_actions.dart';
import '../chat-timeline/save_message_attachments.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../tiptap_plain_text.dart';
import 'message_selection.dart';
import 'selection_action_bar.dart';
import 'selection_menu_state.dart';

/// Builds the bar's buttons in Signal's order — Reply, Forward, Save, Copy,
/// Edit, Delete — from the rules in [selectionMenuState].
///
/// Every action closes the mode when it is done, which is Signal's
/// `finishActionMode()` at the end of each handler: a selection that outlives
/// the thing it was made for is a bar the user has to dismiss by hand.
List<SelectionAction> selectionActions({
  required BuildContext context,
  required WidgetRef ref,
  required List<ChatMessage> selected,
  required bool canMessage,
}) {
  final chat = ref.read(chatProvider);
  final menu = selectionMenuState(
    selected: selected,
    currentUserId: chat.currentUserId,
    canMessage: canMessage && (_perms(ref)?.canSend ?? true),
    // A member barred from forwarding (server 0157) is treated as a private
    // group would be: nothing leaves by forward.
    groupPrivacy:
        (ref.read(activeConversationProvider)?.groupPrivacy ?? false) ||
        !(_perms(ref)?.canForward ?? true),
  );
  String tr(String key) => AppTranslations.translate(context, ref, key);
  void done() => ref.read(messageSelectionProvider.notifier).clear();
  final single = selected.length == 1 ? selected.first : null;

  return [
    if (menu.reply && single != null)
      SelectionAction(
        icon: Icons.reply_rounded,
        label: tr('chat_reply'),
        onPressed: () {
          ref.read(chatProvider.notifier).setReplyToMessage(single);
          done();
        },
      ),
    if (menu.forward)
      SelectionAction(
        icon: Icons.shortcut_rounded,
        label: tr('chat_forward'),
        onPressed: () async {
          await showForwardMessages(context, ref, selected);
          done();
        },
      ),
    if (menu.save && single != null)
      SelectionAction(
        icon: Icons.save_alt_rounded,
        label: tr('chat_save_to_phone'),
        onPressed: () async {
          await saveMessageAttachments(context, ref, single);
          done();
        },
      ),
    if (menu.copy)
      SelectionAction(
        icon: Icons.content_copy_outlined,
        label: tr('chat_copy'),
        onPressed: () async {
          await copySelectedMessages(context, ref, selected);
          done();
        },
      ),
    if (menu.edit && single != null)
      SelectionAction(
        icon: Icons.edit_outlined,
        label: tr('chat_edit'),
        onPressed: () async {
          await editMessageFlow(context, ref, single);
          done();
        },
      ),
    if (menu.delete)
      SelectionAction(
        icon: Icons.delete_outline_rounded,
        label: tr('chat_delete'),
        onPressed: () async {
          final deleted = await deleteSelectedMessages(
            context,
            ref,
            selected,
            canDeleteForEveryone: menu.deleteForEveryone,
          );
          if (deleted) done();
        },
      ),
  ];
}

/// One clipboard entry, the messages in timeline order separated by newlines —
/// Signal's `copyToClipboard`, which sorts by date and joins the bodies.
Future<void> copySelectedMessages(
  BuildContext context,
  WidgetRef ref,
  List<ChatMessage> selected,
) async {
  final ordered = [...selected]
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final text = ordered
      .map((m) => tiptapToPlainText(m.body).trim())
      .where((line) => line.isNotEmpty)
      .join('\n');
  if (text.isEmpty) return;
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  showAppToast(
    context,
    AppTranslations.translate(context, ref, 'chat_copied_clipboard'),
  );
}

/// Asks for me / for everyone, then deletes one by one. Returns false when the
/// user backed out, so the selection stays up rather than quietly emptying.
Future<bool> deleteSelectedMessages(
  BuildContext context,
  WidgetRef ref,
  List<ChatMessage> selected, {
  required bool canDeleteForEveryone,
}) async {
  String tr(String key) => AppTranslations.translate(context, ref, key);
  final scope = await showDeleteMessageDialog(
    context,
    ref,
    count: selected.length,
    canDeleteForEveryone: canDeleteForEveryone,
  );
  if (scope == null) return false;

  final notifier = ref.read(chatProvider.notifier);
  var failed = 0;
  for (final message in selected) {
    try {
      scope == MessageDeleteScope.everyone
          ? await notifier.deleteMessage(message.id)
          : await notifier.hideMessage(message.id);
    } catch (_) {
      // One refusal must not abandon the rest of the batch; the count is
      // reported once at the end.
      failed++;
    }
  }
  if (failed > 0 && context.mounted) {
    showAppToast(context, tr('chat_delete_selected_failed'), isError: true);
  }
  return true;
}

GroupPermissions? _perms(WidgetRef ref) {
  final conversation = ref.read(activeConversationProvider);
  return conversation == null ? null : GroupPermissions(conversation);
}
