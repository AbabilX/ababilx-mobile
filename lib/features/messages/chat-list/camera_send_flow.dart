import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../../attachments/providers/attachment_providers.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_connections_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/messageable_people_provider.dart';
import 'camera_capture.dart';
import 'camera_recipient_screen.dart';

Future<void> captureAndSendChatPhoto(
  BuildContext context,
  WidgetRef ref,
) async {
  try {
    final capture = await captureForChat(ref);
    if (capture == null || capture.isEmpty || !context.mounted) return;
    await ref.read(chatConnectionsProvider.notifier).refresh();
    if (!context.mounted) return;

    final selected = await showCameraRecipientPicker(
      context,
      ref.read(messageablePeopleProvider),
      capture.files.first.bytes,
    );
    if (selected == null || !context.mounted) return;

    _showSending(context, ref);
    final notifier = ref.read(chatProvider.notifier);
    final conversation = await notifier.startDm(selected.userId);
    await _uploadAndSend(ref, notifier, conversation.id, capture);
    if (context.mounted) context.push('/messages/${conversation.id}');
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_tr(context, ref, 'chat_camera_send_failed'))),
    );
  }
}

/// One message carrying everything the camera flow produced. A failed upload
/// gives back the object it reserved, so an abandoned send is not charged to
/// the conversation's storage.
Future<void> _uploadAndSend(
  WidgetRef ref,
  ChatNotifier notifier,
  String conversationId,
  ChatCameraCapture capture,
) async {
  final attachments = <ChatAttachmentInput>[];
  final reserved = <String>[];
  try {
    for (final picked in capture.files) {
      final presign = await notifier.presignAttachment(
        conversationId,
        contentType: picked.contentType,
        fileName: picked.fileName,
        sizeBytes: picked.sizeBytes,
      );
      reserved.add(presign.publicUrl);
      await notifier.uploadAttachmentBytes(
        presign,
        picked.bytes,
        picked.contentType,
      );
      await ref
          .read(attachmentAdopterProvider)
          .adoptBytes(
            fileUrl: presign.publicUrl,
            fileName: picked.fileName,
            contentType: picked.contentType,
            bytes: picked.bytes,
          );
      attachments.add(
        ChatAttachmentInput(
          fileUrl: presign.publicUrl,
          fileName: picked.fileName,
          contentType: picked.contentType,
          sizeBytes: picked.sizeBytes,
        ),
      );
    }
    await notifier.sendMessage(
      conversationId: conversationId,
      body: capture.caption,
      attachments: attachments,
    );
  } catch (_) {
    for (final url in reserved) {
      await notifier.discardUpload(conversationId, url);
    }
    rethrow;
  }
}

@visibleForTesting
Future<ChatUserSummary?> showCameraRecipientPicker(
  BuildContext context,
  List<ChatUserSummary> people,
  Uint8List photoBytes,
) {
  // The camera starts inside HomeShell's nested navigator. Present the
  // recipient picker on the root so the shell bar cannot cover its send bar.
  return Navigator.of(context, rootNavigator: true).push<ChatUserSummary>(
    MaterialPageRoute(
      builder: (_) =>
          CameraRecipientScreen(photoBytes: photoBytes, people: people),
    ),
  );
}

void _showSending(BuildContext context, WidgetRef ref) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(_tr(context, ref, 'chat_photo_sending'))),
  );
}

String _tr(BuildContext context, WidgetRef ref, String key) =>
    AppTranslations.translate(context, ref, key);
