import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_toast.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'mute_choice.dart';
import 'mute_options_sheet.dart';

/// The one mute gesture every entry point shares (details, chat-list long
/// press). Muted → unmute at once, Signal's arrangement: there is nothing to
/// choose. Not muted → the options sheet, then the write.
///
/// [context] must outlive the sheet — pass the screen's, never a sheet's.
Future<void> changeConversationMute(
  BuildContext context,
  WidgetRef ref,
  ChatConversation conversation,
) async {
  MuteChoice? choice;
  if (!conversation.isMutedNow) {
    choice = await showMuteOptionsSheet(
      context,
      allowMentionsOnly: conversation.isGroupConversation,
    );
    if (choice == null) return;
  }
  try {
    await ref.read(chatProvider.notifier).setMute(conversation.id, choice);
  } catch (_) {
    if (!context.mounted) return;
    showAppToast(
      context,
      choice == null
          ? 'Could not unmute this chat'
          : 'Could not mute this chat',
      isError: true,
    );
  }
}
