import 'dart:io';
import 'dart:typed_data';

import 'package:ababilx/features/attachments/crypto/attachment_file_cipher.dart';
import 'package:ababilx/features/attachments/crypto/attachment_secret.dart';
import 'package:ababilx/features/attachments/data/local/attachment_blob_store.dart';
import 'package:ababilx/features/attachments/data/local/attachment_dedupe_store.dart';
import 'package:ababilx/features/attachments/data/models/attachment_handle.dart';
import 'package:ababilx/features/attachments/services/attachment_cipher.dart';
import 'package:ababilx/features/attachments/services/attachment_downloader.dart';
import 'package:ababilx/features/attachments/services/attachment_paths.dart';
import 'package:ababilx/features/attachments/services/attachment_queue.dart';
import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/data/models/chat_attachment.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// An encrypted attachment (server 0168) through the real download queue:
/// what the server holds is ciphertext, and what lands in the attachment
/// store — the only thing a renderer ever reads — is the file.
void main() {
  final key = List<int>.generate(32, (i) => 255 - i);
  final plain = Uint8List.fromList(
    List<int>.generate(150000, (i) => (i * 7 + 3) & 0xff),
  );

  late Directory temp;
  late ChatLocalDb db;
  late HttpServer server;
  late AttachmentQueue queue;
  late Uint8List served;
  var requests = 0;

  setUp(() async {
    requests = 0;
    temp = await Directory.systemTemp.createTemp('ababilx-sealed-test-');
    db = ChatLocalDb.forTesting(NativeDatabase.memory());
    served = await AttachmentFileCipher.sealBytes(plain, key);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests++;
      request.response.contentLength = served.length;
      request.response.add(served);
      await request.response.close();
    });
    queue = AttachmentQueue(
      AttachmentBlobStore(db),
      AttachmentDedupeStore(db),
      AttachmentPaths(rootDirectory: () async => temp),
      AttachmentDownloader(Dio(), const PassthroughAttachmentCipher()),
    );
  });

  tearDown(() async {
    queue.dispose();
    await server.close(force: true);
    await db.close();
    await temp.delete(recursive: true);
  });

  /// The row as the server serves it: generic name, coarse type, the
  /// ciphertext's size and a sealed key.
  ChatMessageAttachment sealedRow() => ChatMessageAttachment(
    id: 'a1',
    messageId: 'm1',
    fileName: 'file',
    fileUrl: 'http://${server.address.host}:${server.port}/chat/c/1.bin',
    contentType: 'image/x-ababilx-sealed',
    sizeBytes: served.length,
    uploadedBy: 'peer',
    createdAt: '',
    encMeta: 'c2VhbGVk',
    encNonce: 'bm9uY2U',
    encKeyVersion: 1,
  );

  ChatMessageAttachment openedRow({List<int>? withKey}) => sealedRow().opened(
    AttachmentSealPayload(
      key: withKey ?? key,
      fileName: 'IMG_0012.jpg',
      contentType: 'image/jpeg',
      plainSize: plain.length,
    ),
  );

  List<File> leftovers() => temp
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => !f.path.endsWith('.jpg'))
      .toList();

  test('ciphertext comes down, the file lands readable', () async {
    final handle = await queue.enqueue(openedRow(), userInitiated: true);
    expect(handle.state, AttachmentTransferState.ready);
    final file = File(handle.localPath!);
    expect(file.path, endsWith('.jpg'), reason: 'named for the REAL type');
    expect(await file.readAsBytes(), plain);
    // Neither the ciphertext copy nor the staging file outlives the download.
    expect(leftovers(), isEmpty);
  });

  test('with no key it is not downloaded, and may be tried again', () async {
    final handle = await queue.enqueue(sealedRow(), userInitiated: true);
    expect(handle.state, AttachmentTransferState.failed);
    expect(requests, 0, reason: 'nothing readable to fetch');
  });

  test('a wrong key leaves nothing readable behind', () async {
    final handle = await queue.enqueue(
      openedRow(withKey: List<int>.filled(32, 1)),
      userInitiated: true,
    );
    expect(handle.state, AttachmentTransferState.permanentlyFailed);
    expect(temp.listSync(recursive: true).whereType<File>(), isEmpty);
  });

  test('a tampered object is refused, not shown', () async {
    served = Uint8List.fromList(served)..[70000] ^= 1;
    final handle = await queue.enqueue(openedRow(), userInitiated: true);
    expect(handle.state, AttachmentTransferState.permanentlyFailed);
    expect(temp.listSync(recursive: true).whereType<File>(), isEmpty);
  });
}
