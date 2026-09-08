import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_toast.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'conversation_actions_sheet.dart';
import 'conversation_end_action.dart';

/// Carries out what the long-press sheet chose.
///
/// It runs on the LIST's context, never the sheet's: the sheet is gone by the
/// time any of this is awaited, and a pin the server refuses has to say so
/// after the round trip.
Future<void> runConversationAction(
  BuildContext context,
  WidgetRef ref,
  ChatConversation conversation,
  String title,
  ConversationAction action,
) async {
  final notifier = ref.read(chatProvider.notifier);
  switch (action) {
    case ConversationAction.pin:
    case ConversationAction.unpin:
      await _pin(
        context,
        notifier,
        conversation.id,
        action == ConversationAction.pin,
      );
    case ConversationAction.mute:
    case ConversationAction.unmute:
      await notifier.muteConversation(
        conversation.id,
        action == ConversationAction.mute,
      );
    case ConversationAction.markRead:
      await notifier.markConversationRead(conversation.id);
    case ConversationAction.end:
      if (!await confirmConversationEndAction(context, conversation, title)) {
        return;
      }
      if (conversation.isGroupConversation) {
        await notifier.leaveChannel(conversation.id);
      } else {
        await notifier.hideDm(conversation.id);
      }
  }
}

/// The pin cap is the server's, so the refusal is too. Naming the limit is
/// what makes the message actionable — "unpin one" is something the user can
/// do, and "failed" is not.
Future<void> _pin(
  BuildContext context,
  ChatNotifier notifier,
  String conversationId,
  bool pinned,
) async {
  try {
    await notifier.pinConversation(conversationId, pinned);
  } catch (e) {
    if (!context.mounted) return;
    showAppToast(
      context,
      e.toString().contains('chat_pin_limit')
          ? 'You can only pin up to 4 chats. Unpin one first.'
          : 'Could not ${pinned ? 'pin' : 'unpin'} this chat',
      isError: true,
    );
  }
}
