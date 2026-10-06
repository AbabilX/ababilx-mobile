import 'dart:io';
import 'dart:typed_data';

import 'package:ababilx/features/attachments/crypto/attachment_crypto_format.dart';
import 'package:ababilx/features/attachments/crypto/attachment_file_cipher.dart';
import 'package:ababilx/features/attachments/crypto/attachment_secret.dart';
import 'package:ababilx/features/attachments/crypto/sealed_upload.dart';
import 'package:ababilx/features/messages/data/models/chat_attachment.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// The upload half of an encrypted attachment (server 0168): what reaches the
/// bucket is ciphertext of the bytes actually sent, and the key stays with
/// the upload until its message is confirmed.
void main() {
  final plain = Uint8List.fromList(
    List<int>.generate(200000, (i) => (i * 13 + 5) & 0xff),
  );
  const url = 'https://cdn.test/chat/c/1.bin';

  AttachmentSecret secretFor(int size) => AttachmentSecret.forUpload(
    fileName: 'IMG_0012.jpg',
    contentType: 'image/jpeg',
    plainSize: size,
  );

  ChatAttachmentInput input() => const ChatAttachmentInput(
    fileUrl: url,
    fileName: 'IMG_0012.jpg',
    contentType: 'image/jpeg',
    sizeBytes: 200000,
  );

  tearDown(() => SealedUploads.forget(url));

  test('the key stays filed until the send is confirmed', () {
    SealedUploads.register(url, secretFor(plain.length));
    // A send that gave up early is sent again from the caller's own list,
    // which never carried the key.
    expect(SealedUploads.attach([input()]).single.secret, isNotNull);
    expect(SealedUploads.attach([input()]).single.secret, isNotNull);
    SealedUploads.forget(url);
    expect(SealedUploads.attach([input()]).single.secret, isNull);
  });

  test('the sealed size follows the bytes uploaded, not the claim', () {
    SealedUploads.register(url, secretFor(123));
    final sized = SealedUploads.sizedFor(url, plain.length)!;
    expect(sized.plainSize, plain.length);
    expect(sized.cipherSize, AttachmentCryptoFormat.cipherSize(plain.length));
    expect(SealedUploads.secretFor(url)!.plainSize, plain.length);
    expect(SealedUploads.sizedFor('https://cdn.test/other', 1), isNull);
  });

  test('encrypting stops at a checkpoint that throws', () async {
    final dir = await Directory.systemTemp.createTemp('ababilx-seal-');
    addTearDown(() => dir.delete(recursive: true));
    final source = File('${dir.path}/in')..writeAsBytesSync(plain);
    var chunks = 0;
    await expectLater(
      AttachmentFileCipher.sealFile(
        source,
        File('${dir.path}/out'),
        List<int>.filled(32, 7),
        checkpoint: () {
          if (++chunks == 2) throw StateError('cancelled');
        },
      ),
      throwsStateError,
    );
    expect(chunks, 2);
  });

  // Cancelled before the first chunk: it must fail the way a cancelled PUT
  // does, because callers treat a normal return as "uploaded".
  test('a cancelled upload fails as cancelled, never as done', () async {
    final dir = await Directory.systemTemp.createTemp('ababilx-seal-');
    addTearDown(() => dir.delete(recursive: true));
    final source = File('${dir.path}/in')..writeAsBytesSync(plain);
    final token = CancelToken()..cancel();
    await expectLater(
      SealedUploads.putFile(
        'http://127.0.0.1:9/put',
        source,
        secretFor(plain.length),
        cancelToken: token,
      ),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );
  });

  group('what is PUT is ciphertext of the file', () {
    late HttpServer server;
    late Future<List<int>> received;
    late int declaredLength;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      received = server.first.then((request) async {
        declaredLength = request.contentLength;
        final body = await request.fold<List<int>>([], (all, part) {
          return all..addAll(part);
        });
        await request.response.close();
        return body;
      });
    });

    tearDown(() => server.close(force: true));

    String uploadUrl() => 'http://${server.address.host}:${server.port}/put';

    Future<void> expectOpens(AttachmentSecret secret) async {
      final body = await received;
      expect(body.length, secret.cipherSize);
      expect(declaredLength, secret.cipherSize);
      expect(
        await AttachmentFileCipher.openBytes(body, secret.key, plain.length),
        plain,
      );
    }

    test('from memory', () async {
      final secret = secretFor(plain.length);
      await SealedUploads.putBytes(uploadUrl(), plain, secret);
      await expectOpens(secret);
    });

    test('from a file', () async {
      final dir = await Directory.systemTemp.createTemp('ababilx-seal-');
      addTearDown(() => dir.delete(recursive: true));
      final source = File('${dir.path}/in')..writeAsBytesSync(plain);
      final secret = secretFor(plain.length);
      await SealedUploads.putFile(uploadUrl(), source, secret);
      await expectOpens(secret);
    });
  });
}
