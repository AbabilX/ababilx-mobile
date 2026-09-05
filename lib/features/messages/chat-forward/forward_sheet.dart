import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../chat-recipient-picker/chat_recipient_picker_screen.dart';
import '../chat-recipient-picker/chat_recipient_target.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';

/// Opens the same full-screen recipient picker as Android Gallery shares.
Future<void> showForwardSheet(
  BuildContext context,
  WidgetRef ref,
  ChatMessage message,
) async {
  await Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(
      builder: (_) => ChatRecipientPickerScreen(
        actionLabel: AppTranslations.translate(context, ref, 'chat_forward'),
        excludedConversationId: message.conversationId,
        onSubmit: (targets, _) => _forward(context, ref, message, targets),
      ),
    ),
  );
}

Future<void> _forward(
  BuildContext context,
  WidgetRef ref,
  ChatMessage message,
  List<ChatRecipientTarget> targets,
) async {
  final chat = ref.read(chatProvider);
  final conversationIds = <String>{};
  final userIds = <String>{};
  for (final target in targets) {
    if (target.kind == ChatRecipientKind.conversation) {
      if (target.id != message.conversationId) conversationIds.add(target.id);
      continue;
    }
    final existing = chat.dms.where((dm) => dm.peerUserId == target.id);
    if (existing.isEmpty || !conversationIds.contains(existing.first.id)) {
      userIds.add(target.id);
    }
  }
  final sent = await ref
      .read(chatProvider.notifier)
      .forwardMessage(
        messageId: message.id,
        conversationIds: conversationIds.toList(),
        userIds: userIds.toList(),
      );
  if (!context.mounted) return;
  if (sent == 0) {
    // Same surface as the success case on purpose. This used to be a bottom
    // SnackBar, which put the two outcomes of one action at opposite ends of
    // the screen.
    showAppToast(
      context,
      AppTranslations.translate(context, ref, 'chat_forward_failed'),
      isError: true,
    );
    return;
  }
  // Toast first, then pop: the entry lives in the root overlay, so it survives
  // the picker closing under it — and closing the picker is the only other
  // thing that happens, which on its own does not say the forward worked.
  showAppToast(context, _forwardedLabel(context, ref, sent));
  Navigator.of(context, rootNavigator: true).pop();
}

String _forwardedLabel(BuildContext context, WidgetRef ref, int sent) {
  if (sent == 1) {
    return AppTranslations.translate(context, ref, 'chat_forwarded_one');
  }
  return AppTranslations.translate(
    context,
    ref,
    'chat_forwarded_many',
  ).replaceAll('{n}', '$sent');
}
