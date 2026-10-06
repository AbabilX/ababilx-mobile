import 'package:ababilx/features/attachments/crypto/attachment_secret.dart';
import 'package:ababilx/features/messages/data/local/chat_key_cache.dart';
import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/message_e2ee/dm_key_rotation.dart';
import 'package:ababilx/features/messages/message_e2ee/message_vault.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'attachment_seal_fakes.dart';

export 'attachment_seal_fakes.dart';

/// One vault, one fake server, and the three things every test here does:
/// unlock, make an encrypted upload, and send it.
class SealHarness {
  SealHarness() {
    final db = ChatLocalDb.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    cache = ChatKeyCache(db);
  }

  final repo = SealFakeRepository();
  final storage = SealFakeStorage();
  late final ChatKeyCache cache;

  /// A vault that has never been unlocked in this process.
  MessageVault locked() => MessageVault(repo, storage, cache);

  Future<MessageVault> unlocked() async {
    final vault = locked();
    await vault.ensureIdentity();
    return vault;
  }

  static ChatAttachmentInput upload({
    String url = 'https://cdn/chat/dm/1.bin',
  }) => ChatAttachmentInput(
    fileUrl: url,
    fileName: 'IMG_0012.jpg',
    contentType: 'image/jpeg',
    sizeBytes: 123456,
    secret: AttachmentSecret(
      key: List<int>.generate(32, (i) => i),
      plainSize: 123456,
      cipherSize: 130000,
      wireName: 'file',
      wireType: 'image/x-ababilx-sealed',
    ),
  );

  /// Sends [text] with [files] into [conversationId] and returns the message
  /// as the server would serve it back.
  Future<ChatMessage> send(
    MessageVault vault,
    String conversationId, {
    String text = '',
    required List<ChatAttachmentInput> files,
  }) => sendEncryptedChat<ChatMessage>(
    vault: vault,
    conversationId: conversationId,
    text: text,
    currentUserId: 'me',
    attachments: files,
    send: (payload) async => servedMessage(conversationId, payload, files),
  );
}
