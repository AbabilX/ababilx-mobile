import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/router/shell_bottom_bar/shell_chrome_provider.dart';
import '../../local_share/data/share_thread_queries.dart';
import '../../local_share/sheets/share_chat_row_sheet.dart';
import '../chat-folders/chat_folder_sheet.dart';
import '../chat-folders/chat_folders.dart';
import '../data/models/chat_models.dart';
import '../nickname/contact_nickname_provider.dart';
import '../nickname/nickname_title.dart';
import '../providers/chat_provider.dart';
import 'conversation_actions_run.dart';
import 'conversation_actions_sheet.dart';

/// Every sheet the chat list raises goes through here.
///
/// The floating nav pill is a `Positioned` in the shell's Stack, painted
/// OVER this branch's navigator — so a sheet raised from the list comes up
/// underneath it, scrim and all. Hiding the bar covers BOTH the chooser and
/// any follow-up sheet (mute options, folders): restoring it in between would
/// paint the pill over the second sheet. The `finally` is load-bearing — a
/// sheet dismissed by a back gesture must not leave the app with no nav.
Future<T?> withNavHidden<T>(WidgetRef ref, Future<T?> Function() open) async {
  final hidden = ref.read(shellBottomBarHiddenProvider.notifier);
  hidden.state = true;
  try {
    return await open();
  } finally {
    hidden.state = false;
  }
}

/// Long press on a row. The sheet only chooses; the action runs on the
/// list's own context, because the sheet is gone before the request comes
/// back and the pin cap is reported after it.
Future<void> openConversationActions(
  BuildContext context,
  WidgetRef ref,
  ChatConversation conversation,
) {
  final title = ref
      .read(contactNicknamesProvider)
      .titleFor(conversation, ref.read(chatProvider).currentUserId);
  return withNavHidden(ref, () async {
    final action = await showConversationActionsSheet(
      context,
      conversation,
      title,
      folderLabel: AppTranslations.translate(
        context,
        ref,
        'chat_folder_add_to',
      ),
    );
    if (action == null || !context.mounted) return;
    await runConversationAction(context, ref, conversation, title, action);
  });
}

Future<void> openShareActions(
  BuildContext context,
  WidgetRef ref,
  ShareThread thread,
) => withNavHidden(ref, () => showShareChatRowSheet(context, ref, thread));

/// New folder or edit one. Returns the saved folder's id.
Future<String?> openFolderSheet(
  BuildContext context,
  WidgetRef ref, [
  ChatFolder? folder,
]) => withNavHidden(ref, () => showChatFolderSheet(context, folder: folder));
