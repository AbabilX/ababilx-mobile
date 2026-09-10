import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/message_e2ee/sidebar_preview.dart';
import 'package:flutter_test/flutter_test.dart';

ChatConversation _row({
  String? body = 'Encrypted message',
  String? cipher = 'c1',
  String? nonce = 'n1',
  int? version = 1,
  String? author = 'alice',
}) => ChatConversation(
  id: 'g1',
  teamId: '',
  scope: 'personal',
  type: 'group',
  createdAt: '2026-09-10T00:00:00Z',
  lastMessageBody: body,
  lastMessageUserId: author,
  lastMessageEncryptedBody: cipher,
  lastMessageEncryptionNonce: nonce,
  lastMessageEncryptionVersion: version,
  lastMessageEncryptionKeyVersion: version == null ? null : 3,
);

ChatMessage _msg({String? cipher, String? nonce}) => ChatMessage(
  id: 'm2',
  conversationId: 'g1',
  userId: 'bob',
  body: 'hi',
  createdAt: '2026-09-10T00:01:00Z',
  encryptedBody: cipher,
  encryptionNonce: nonce,
  encryptionVersion: cipher == null ? null : 1,
  encryptionKeyVersion: cipher == null ? null : 4,
);

void main() {
  group('hasSealedPreview', () {
    test('a sealed group row can be opened, not only a DM', () {
      expect(hasSealedPreview(_row()), isTrue);
    });

    test('a plaintext row has nothing to open', () {
      final plain = _row(
        body: 'hello',
        cipher: null,
        nonce: null,
        version: null,
      );
      expect(hasSealedPreview(plain), isFalse);
    });

    test('no author means no AAD, so nothing to try', () {
      expect(hasSealedPreview(_row(author: null)), isFalse);
    });
  });

  test('the stand-in message carries what the cipher binds', () {
    final m = sealedPreviewMessage(_row());
    expect(m.userId, 'alice');
    expect(m.conversationId, 'g1');
    expect(m.encryptedBody, 'c1');
    expect(m.encryptionNonce, 'n1');
    expect(m.encryptionKeyVersion, 3);
    expect(m.isEncrypted, isTrue);
  });

  group('previewStillCurrent', () {
    final opened = _row(body: 'see you at 5');

    test('same ciphertext, still a placeholder: write it', () {
      expect(previewStillCurrent(_row(), opened), isTrue);
    });

    test('a failed decrypt is still a placeholder worth replacing', () {
      final failed = _row(body: 'Unable to decrypt this message');
      expect(previewStillCurrent(failed, opened), isTrue);
    });

    test('a newer message arrived meanwhile: drop the older text', () {
      expect(previewStillCurrent(_row(cipher: 'c2'), opened), isFalse);
    });

    test('text already on screen is never replaced', () {
      expect(previewStillCurrent(_row(body: 'newer'), opened), isFalse);
    });
  });

  group('previewForDisk', () {
    test('sealed text never reaches disk; its ciphertext does', () {
      final disk = previewForDisk(_row(body: 'secret'));
      expect(disk.lastMessageBody, 'Encrypted message');
      expect(disk.lastMessageEncryptedBody, 'c1');
      expect(hasSealedPreview(disk), isTrue);
    });

    test('a plaintext channel row is written as it is', () {
      final plain = _row(body: 'standup at 10', cipher: null, version: null);
      expect(previewForDisk(plain).lastMessageBody, 'standup at 10');
    });
  });

  group('withLastMessageCipher', () {
    test('a sealed message brings its own ciphertext', () {
      final next = withLastMessageCipher(
        _row(),
        _msg(cipher: 'c2', nonce: 'n2'),
      );
      expect(next.lastMessageEncryptedBody, 'c2');
      expect(next.lastMessageEncryptionNonce, 'n2');
      expect(next.lastMessageEncryptionKeyVersion, 4);
    });

    test('a plaintext message clears the previous ciphertext', () {
      final next = withLastMessageCipher(_row(), _msg());
      expect(next.lastMessageEncryptedBody, isNull);
      expect(next.lastMessageEncryptionVersion, isNull);
      expect(hasSealedPreview(next), isFalse);
    });
  });
}
