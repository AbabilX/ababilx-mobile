import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/media/picked_media_file.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../chat_list_filters.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';

Future<void> captureAndSendChatPhoto(
  BuildContext context,
  WidgetRef ref,
) async {
  try {
    final picked = await pickLiveCameraFile();
    if (picked == null || !context.mounted) return;

    final chat = ref.read(chatProvider);
    final conversations = unifiedConversations(
      dms: chat.dms,
      channels: chat.channels,
    ).where((item) => item.canMessage).toList();
    final selected = await _chooseConversation(
      context,
      ref,
      conversations,
      chat.currentUserId,
    );
    if (selected == null || !context.mounted) return;

    _showSending(context, ref);
    final notifier = ref.read(chatProvider.notifier);
    final presign = await notifier.presignAttachment(
      selected.id,
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
        conversationId: selected.id,
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
      await notifier.discardUpload(selected.id, presign.publicUrl);
      rethrow;
    }
    if (context.mounted) context.push('/messages/${selected.id}');
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_tr(context, ref, 'chat_camera_send_failed'))),
    );
  }
}

Future<ChatConversation?> _chooseConversation(
  BuildContext context,
  WidgetRef ref,
  List<ChatConversation> conversations,
  String? currentUserId,
) {
  return showModalBottomSheet<ChatConversation>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * .62,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _tr(sheetContext, ref, 'chat_send_to'),
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
            ),
            Expanded(
              child: conversations.isEmpty
                  ? Center(child: Text(_tr(sheetContext, ref, 'chat_no_chats')))
                  : ListView.builder(
                      itemCount: conversations.length,
                      itemBuilder: (_, index) {
                        final item = conversations[index];
                        final title = item.displayTitle(currentUserId);
                        return ListTile(
                          leading: AppAvatar(
                            size: 48,
                            url: item.peerUserAvatar,
                            name: title,
                          ),
                          title: Text(title),
                          onTap: () => Navigator.pop(sheetContext, item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
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
