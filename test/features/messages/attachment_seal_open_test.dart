import 'dart:convert';

import 'package:ababilx/features/messages/message_e2ee/message_vault.dart';
import 'package:ababilx/features/messages/message_e2ee/vault_placeholder.dart';
import 'package:flutter_test/flutter_test.dart';

import 'attachment_seal_harness.dart';

/// Encrypted chat files (server 0168): the vault seals a file's key under the
/// conversation key on send and opens it again on receive.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SealHarness h;
  setUp(() => h = SealHarness());

  test('the file key is sealed under the body key version and opens', () async {
    final vault = await h.unlocked();
    final served = await h.send(
      vault,
      'dm',
      text: 'look',
      files: [SealHarness.upload()],
    );
    final row = served.attachments.single;
    expect(row.isSealed, isTrue);
    expect(row.needsKey, isTrue);
    expect(row.encKeyVersion, served.encryptionKeyVersion);
    expect(row.fileName, 'file');

    final opened = await vault.decryptMessage(served, 'me');
    final file = opened.attachments.single;
    expect(opened.body, 'look');
    expect(file.needsKey, isFalse);
    expect(file.fileName, 'IMG_0012.jpg');
    expect(file.contentType, 'image/jpeg');
    expect(file.sizeBytes, 123456);
    expect(file.secret!.key, List<int>.generate(32, (i) => i));
    expect(file.secret!.cipherSize, 130000);
  });

  test('an opened attachment is written back to disk sealed', () async {
    final vault = await h.unlocked();
    final opened = await vault.decryptMessage(
      await h.send(vault, 'dm', text: 'x', files: [SealHarness.upload()]),
      'me',
    );
    final disk = jsonEncode(opened.attachments.single.toJson());
    expect(disk, isNot(contains('IMG_0012')));
    expect(disk, contains('"file_name":"file"'));
    expect(disk, contains('"size_bytes":130000'));
    expect(disk, contains('enc_meta'));
    expect(disk, isNot(contains('AAECAwQF')));
  });

  test(
    'a message of files only is sealed, and its empty text is real',
    () async {
      final vault = await h.unlocked();
      final served = await h.send(vault, 'dm', files: [SealHarness.upload()]);
      expect(served.isEncrypted, isTrue);
      final opened = await vault.decryptMessage(served, 'me');
      expect(opened.body, '');
      expect(isUnopenedMessage(opened), isFalse);

      // Locked, the same row is unopened: nothing may retry or forward it.
      final locked = await h.locked().decryptMessage(served, 'me');
      expect(locked.attachments.single.needsKey, isTrue);
      expect(isUnopenedMessage(locked), isTrue);
    },
  );

  test(
    'a seal moved to another conversation or sender does not open',
    () async {
      final vault = await h.unlocked();
      final served = await h.send(
        vault,
        'dm',
        text: 'x',
        files: [SealHarness.upload()],
      );
      await h.send(vault, 'other', text: 'y', files: [SealHarness.upload()]);
      final row = served.attachments.single;

      final elsewhere = await vault.openAttachment(
        conversationId: 'other',
        currentUserId: 'me',
        attachment: row,
      );
      expect(elsewhere.needsKey, isTrue);

      final forged = await vault.openAttachment(
        conversationId: 'dm',
        currentUserId: 'me',
        attachment: row,
        sealerId: 'somebody-else',
      );
      expect(forged.needsKey, isTrue);
    },
  );
}
