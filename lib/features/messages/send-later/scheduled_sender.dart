import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../attachments/crypto/sealed_upload.dart';
import '../data/chat_client_message_id.dart';
import '../data/chat_send_body.dart';
import '../data/models/chat_models.dart';
import '../message_e2ee/dm_key_rotation.dart';
import '../message_e2ee/encryption_pins.dart';
import '../message_e2ee/message_vault.dart';
import '../providers/chat_provider.dart';
import 'scheduled_api.dart';
import 'scheduled_message.dart';
import 'scheduled_provider.dart';

final scheduledSenderProvider = Provider((ref) => ScheduledSender(ref));

/// Stores a message to be sent later (server 0171).
///
/// It is sealed here, now, exactly as a message sent by hand is — body and
/// each file's key under the conversation key — and the server keeps that
/// request until the time comes. No pending bubble and no outbox row: until
/// the server sends it, it is not a message.
class ScheduledSender {
  ScheduledSender(this._ref);

  final Ref _ref;

  Future<ScheduledMessage> schedule({
    required String conversationId,
    required DateTime sendAt,
    required String body,
    List<ChatAttachmentInput> attachments = const [],
    List<String> mentionedUserIds = const [],
    String? parentId,
    String? quotedMessageId,
    String? taskPriority,
  }) async {
    final client = _ref.read(apiClientProvider);
    final userId = await _ref.read(chatProvider.notifier).ensureCurrentUserId();
    final conv = _ref.read(chatProvider).conversationById(conversationId);
    final files = SealedUploads.attach(attachments);
    final clientRef = newChatClientMessageId();

    Future<ScheduledMessage> store(EncryptedDmPayload? sealed) =>
        createScheduled(
          client,
          conversationId,
          sendAt: sendAt,
          request: chatSendBody(
            clientMessageId: clientRef,
            body: sealed == null ? body : '',
            encryptedBody: sealed?.encryptedBody,
            encryptionNonce: sealed?.nonce,
            encryptionVersion: sealed == null ? null : 1,
            encryptionKeyVersion: sealed?.keyVersion,
            parentId: parentId,
            quotedMessageId: quotedMessageId,
            attachments: [
              for (final a in files)
                a.withSeal(sealed?.attachmentSeals[a.fileUrl]),
            ],
            mentionedUserIds: mentionedUserIds,
            taskPriority: taskPriority,
          ),
        );

    final hasSealedFile = files.any((a) => a.secret != null);
    final ScheduledMessage row;
    final pinned = await _ref
        .read(encryptionPinsProvider)
        .isPinned(userId, conversationId);
    if (mustSealChat(pinned: pinned, conversation: conv) &&
        (body.isNotEmpty || hasSealedFile)) {
      // Same rule as a send: a refusal that means the key is stale re-keys
      // once and stores the message sealed under the new one.
      row = await sendEncryptedChat(
        vault: _ref.read(messageVaultProvider),
        conversationId: conversationId,
        text: body,
        currentUserId: userId,
        attachments: files,
        send: store,
        sendUnencrypted: mayStayPlaintext(pinned: pinned, conversation: conv)
            ? () => store(null)
            : null,
      );
    } else {
      row = await store(null);
    }
    for (final a in files) {
      SealedUploads.forget(a.fileUrl);
    }
    _ref.invalidate(scheduledMessagesProvider(conversationId));
    return row;
  }
}
