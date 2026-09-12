import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../chat-recipient-picker/chat_recipient_picker_screen.dart';
import '../data/models/chat_models.dart';
import 'forward_send.dart';

/// Opens the same full-screen recipient picker as Android Gallery shares.
Future<void> showForwardSheet(
  BuildContext context,
  WidgetRef ref,
  ChatMessage message,
) => showForwardMessages(context, ref, [message]);

/// The multi-select forward: one picker, one confirmation, N messages sent to
/// each destination in the order they were written.
Future<void> showForwardMessages(
  BuildContext context,
  WidgetRef ref,
  List<ChatMessage> messages,
) async {
  if (messages.isEmpty) return;
  await Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(
      builder: (_) => ChatRecipientPickerScreen(
        actionLabel: AppTranslations.translate(context, ref, 'chat_forward'),
        excludedConversationId: messages.first.conversationId,
        onSubmit: (targets, _) =>
            forwardMessages(context, ref, messages, targets),
      ),
    ),
  );
}
