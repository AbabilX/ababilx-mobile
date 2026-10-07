import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../privacy-mode/privacy_media.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../tiptap_encode.dart';
import 'task_card_data.dart';

/// Posts a task card into [conversationId]: an ordinary message — sealed and
/// retried like any other — that the server marks as a task.
///
/// False when the sender backed out of the privacy-mode media sheet. A send
/// that fails afterwards is the chat's own failed bubble with its retry.
Future<bool> sendTask(
  BuildContext context,
  WidgetRef ref, {
  required String conversationId,
  required String title,
  required String description,
  required TaskPriority priority,
  required List<ChatAttachmentInput> attachments,
}) async {
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
      body: encodeTiptapBody(plain: taskBodyText(title, description)),
      attachments: files,
      taskPriority: priority.wire,
    ),
  );
  return true;
}
