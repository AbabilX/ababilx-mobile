import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/media/picked_media_file.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_connections_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/messageable_people_provider.dart';
import 'camera_recipient_screen.dart';

Future<void> captureAndSendChatPhoto(
  BuildContext context,
  WidgetRef ref,
) async {
  try {
    final picked = await pickLiveCameraFile();
    if (picked == null || !context.mounted) return;
    await ref.read(chatConnectionsProvider.notifier).refresh();
    if (!context.mounted) return;

    final selected = await _chooseRecipient(
      context,
      ref.read(messageablePeopleProvider),
      picked.bytes,
    );
    if (selected == null || !context.mounted) return;

    _showSending(context, ref);
    final notifier = ref.read(chatProvider.notifier);
    final conversation = await notifier.startDm(selected.userId);
    final presign = await notifier.presignAttachment(
      conversation.id,
      contentType: picked.contentType,
      fileName: picked.fileName,
      sizeBytes: picked.sizeBytes,
    );
    try {
      await notifier.uploadAttachmentBytes(
        presign,
        picked.bytes,
        picked.contentType,
      );
      await notifier.sendMessage(
        conversationId: conversation.id,
        body: '',
        attachments: [
          ChatAttachmentInput(
            fileUrl: presign.publicUrl,
            fileName: picked.fileName,
            contentType: picked.contentType,
            sizeBytes: picked.sizeBytes,
          ),
        ],
      );
    } catch (_) {
      await notifier.discardUpload(conversation.id, presign.publicUrl);
      rethrow;
    }
    if (context.mounted) context.push('/messages/${conversation.id}');
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_tr(context, ref, 'chat_camera_send_failed'))),
    );
  }
}

Future<ChatUserSummary?> _chooseRecipient(
  BuildContext context,
  List<ChatUserSummary> people,
  Uint8List photoBytes,
) {
  return Navigator.of(context).push<ChatUserSummary>(
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
