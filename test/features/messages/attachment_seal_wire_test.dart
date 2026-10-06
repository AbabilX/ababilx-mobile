import 'dart:convert';

import 'package:ababilx/features/attachments/crypto/attachment_secret.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'attachment_seal_harness.dart';

/// Encrypted chat files (server 0168): what crosses the API. The file's key
/// travels sealed under the conversation key, beside the attachment row —
/// these strings are the wire format, shared with every other client.
void main() {
  ChatAttachmentInput upload() => SealHarness.upload();

  test('the sealed payload is this exact JSON', () {
    final payload = AttachmentSealPayload(
      key: List<int>.generate(32, (i) => i),
      fileName: 'IMG_0012.jpg',
      contentType: 'image/jpeg',
      plainSize: 123456,
    );
    expect(
      utf8.decode(payload.encode()),
      '{"v":1,"k":"AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8",'
      '"n":"IMG_0012.jpg","t":"image/jpeg","s":123456}',
    );
    final back = AttachmentSealPayload.decode(payload.encode());
    expect(back.key, payload.key);
    expect(back.fileName, 'IMG_0012.jpg');
    expect(back.plainSize, 123456);
  });

  test('the AAD names conversation, key version and sealer', () {
    expect(
      utf8.decode(attachmentSealAad('conv-1', 3, 'user-9')),
      'ababilx-att-meta-v1:conv-1:3:user-9',
    );
  });

  test('a payload of another version or a short key is refused', () {
    List<int> raw(Map<String, dynamic> json) => utf8.encode(jsonEncode(json));
    expect(
      () => AttachmentSealPayload.decode(raw({'v': 2, 'k': 'AAAA', 's': 1})),
      throwsFormatException,
    );
    expect(
      () => AttachmentSealPayload.decode(raw({'v': 1, 'k': 'AAAA', 's': 1})),
      throwsFormatException,
    );
  });

  test('the server is told the kind of file and nothing else', () {
    expect(
      SealedAttachmentWire.type('image/heic', 'IMG.HEIC'),
      'image/x-ababilx-sealed',
    );
    // Pickers hand over octet-stream for plenty of photos.
    expect(
      SealedAttachmentWire.type('application/octet-stream', 'a.JPG'),
      'image/x-ababilx-sealed',
    );
    expect(
      SealedAttachmentWire.type('application/pdf', 'tax.pdf'),
      'application/octet-stream',
    );
    expect(
      SealedAttachmentWire.name('audio/mp4', 'voice-message-12s.m4a'),
      'voice-message',
    );
    expect(SealedAttachmentWire.name('audio/mpeg', 'song.mp3'), 'file');
    expect(SealedAttachmentWire.name('image/jpeg', 'passport.jpg'), 'file');
  });

  test('an encrypted upload never goes out with its real name', () {
    final seal = const SealedAttachmentMeta(
      encMeta: 'bWV0YQ',
      encNonce: 'bm9uY2U',
    );
    final wire = upload().withSeal(seal).toWire();
    expect(wire, {
      'file_url': 'https://cdn/chat/dm/1.bin',
      'file_name': 'file',
      'content_type': 'image/x-ababilx-sealed',
      'size_bytes': 130000,
      'enc_meta': 'bWV0YQ',
      'enc_nonce': 'bm9uY2U',
    });
    expect(jsonEncode(wire), isNot(contains('IMG_0012')));
    expect(wire.containsKey('secret'), isFalse);
  });

  test('with no seal it refuses rather than send an unopenable file', () {
    expect(() => upload().toWire(), throwsStateError);
  });

  test('the outbox copy keeps the key; a seal is never stored', () {
    final stored = upload()
        .withSeal(const SealedAttachmentMeta(encMeta: 'a', encNonce: 'b'))
        .toJson();
    final back = ChatAttachmentInput.fromJson(
      jsonDecode(jsonEncode(stored)) as Map<String, dynamic>,
    );
    expect(back.secret!.key, List<int>.generate(32, (i) => i));
    expect(back.secret!.cipherSize, 130000);
    expect(back.fileName, 'IMG_0012.jpg');
    expect(back.seal, isNull);
  });
}
