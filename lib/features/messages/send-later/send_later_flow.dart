import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../privacy-mode/privacy_media.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'scheduled_sender.dart';
import 'send_later_sheet.dart';
import 'send_later_times.dart';
import 'send_later_words.dart';

/// Why this chat takes no scheduled message, or null when it does. The
/// server holds the same rule (`ScheduledRefusal`); asked here first so a
/// long press answers at once.
String? sendLaterRefusal(ChatConversation? conversation) {
  if (conversation == null) return null;
  if (conversation.privateChat) {
    return 'Send later is off while private chat is on.';
  }
  if (conversation.isSelf || conversation.isWebhook) {
    return 'Send later is not available in this chat.';
  }
  return null;
}

/// Long press on a send button: asks when, returns the time or null. Says
/// why when this chat cannot schedule.
Future<DateTime?> pickSendLaterTime(
  BuildContext context,
  WidgetRef ref,
  String conversationId,
) async {
  final refusal = sendLaterRefusal(
    ref.read(chatProvider).conversationById(conversationId),
  );
  if (refusal != null) {
    showAppToast(context, refusal, isError: true);
    return null;
  }
  HapticFeedback.mediumImpact();
  return showSendLaterSheet(context);
}

/// Schedules what a composer holds. True when it was stored — the caller
/// then clears itself, as after a send; false leaves everything in place.
Future<bool> sendLater(
  BuildContext context,
  WidgetRef ref, {
  required String conversationId,
  required String body,
  required List<ChatAttachmentInput> attachments,
  List<String> mentionedUserIds = const [],
  String? parentId,
  String? quotedMessageId,
  String? taskPriority,
  DateTime? at,
}) async {
  final sendAt = at ?? await pickSendLaterTime(context, ref, conversationId);
  if (sendAt == null || !context.mounted) return false;
  // Privacy mode's saving choice still applies to a scheduled file.
  final ruled = await askPrivacyMediaRules(
    context,
    ref,
    ref.read(chatProvider).conversationById(conversationId),
    attachments,
  );
  if (ruled == null || !context.mounted) return false;
  // A timed photo's clock and withheld URL belong to a sent message.
  if (ruled.any((a) => a.viewSeconds != null)) {
    showAppToast(context, 'A timed photo cannot be sent later.', isError: true);
    return false;
  }
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  try {
    await ref
        .read(scheduledSenderProvider)
        .schedule(
          conversationId: conversationId,
          sendAt: sendAt,
          body: body,
          attachments: ruled,
          mentionedUserIds: mentionedUserIds,
          parentId: parentId,
          quotedMessageId: quotedMessageId,
          taskPriority: taskPriority,
        );
    showAppToastIn(overlay, 'Scheduled for ${formatSendAt(sendAt)}');
    return true;
  } catch (error) {
    showAppToastIn(overlay, sendLaterErrorText(error), isError: true);
    return false;
  }
}
