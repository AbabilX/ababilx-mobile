import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../privacy-mode/privacy_media.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../send-later/send_later_flow.dart';
import '../tiptap_encode.dart';
import 'task_card_data.dart';

/// Posts a task card into [conversationId]: an ordinary message — sealed and
/// retried like any other — that the server marks as a task.
///
/// With [sendAt] the card is stored on the server and sent at that time.
///
/// False when the sender backed out of the privacy-mode media sheet, or the
/// card could not be scheduled. A send
/// that fails afterwards is the chat's own failed bubble with its retry.
Future<bool> sendTask(
  BuildContext context,
  WidgetRef ref, {
  required String conversationId,
  required String title,
  required String description,
  required TaskPriority priority,
  required List<ChatAttachmentInput> attachments,
  DateTime? sendAt,
}) async {
  final body = encodeTiptapBody(plain: taskBodyText(title, description));
  // Send later (server 0171): stored to go out at [sendAt]; it asks the
  // privacy-mode sheet itself.
  if (sendAt != null) {
    return sendLater(
      context,
      ref,
      conversationId: conversationId,
      body: body,
      attachments: attachments,
      taskPriority: priority.wire,
      at: sendAt,
    );
  }
  var files = attachments;
  if (files.isNotEmpty) {
    final ruled = await askPrivacyMediaRules(
      context,
      ref,
      ref.read(chatProvider).conversationById(conversationId),
      files,
    );
    if (ruled == null) return false;
    files = List.of(ruled);
  }
  final notifier = ref.read(chatProvider.notifier);
  // A task is not a reply: a banner left up in the composer stays there.
  unawaited(
    notifier.sendMessage(
      conversationId: conversationId,
      body: body,
      attachments: files,
      taskPriority: priority.wire,
    ),
  );
  return true;
}
