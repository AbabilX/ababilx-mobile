import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ababilx/features/attachments/data/local/attachment_blob_store.dart';
import 'package:ababilx/features/attachments/data/models/attachment_url_key.dart';
import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/data/local/chat_message_store.dart';
import 'package:ababilx/features/messages/data/models/chat_attachment.dart';
import 'package:ababilx/features/messages/data/models/chat_message.dart';
import 'package:ababilx/features/messages/history-transfer/history_transfer_api.dart';
import 'package:ababilx/features/messages/history-transfer/history_transfer_codec.dart';
import 'package:ababilx/features/messages/history-transfer/history_transfer_crypto.dart';
import 'package:ababilx/features/messages/history-transfer/history_transfer_exporter.dart';
import 'package:ababilx/features/messages/history-transfer/history_transfer_manifest.dart';
import 'package:ababilx/features/messages/history-transfer/history_transfer_snapshot.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the relay. Objects land in a map keyed by chunk index, which
/// is all the exporter ever needs of the server.
class _FakeApi implements HistoryTransferApi {
  final Map<int, List<int>> objects = {};
  final Set<int> settled = {};
  final List<int> reserved = [];
  String? manifestCiphertext;
  int? manifestChunks;

  @override
  Future<HistoryTransferSlot> reserveChunk({
    required String id,
    required int index,
    required String kind,
    required int sizeBytes,
  }) async {
    reserved.add(index);
    return HistoryTransferSlot(
      uploadUrl: 'obj://$index',
      alreadyUploaded: settled.contains(index),
    );
  }

  @override
  Future<void> putChunk(String uploadUrl, List<int> bytes) async =>
      objects[int.parse(uploadUrl.split('//').last)] = bytes;

  @override
  Future<void> confirmChunk({
    required String id,
    required int index,
    required String checksum,
  }) async {
    // The server verifies size itself; the checksum travels for the
    // destination, so the only thing worth asserting here is that it is of the
    // SEALED bytes we actually sent.
    expect(checksum, sha256.convert(objects[index]!).toString());
  }

  @override
  Future<void> commitManifest({
    required String id,
    required String ciphertext,
    required int chunks,
  }) async {
    manifestCiphertext = ciphertext;
    manifestChunks = chunks;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} is the destination\'s');
}

ChatMessage _msg(int i, {List<ChatMessageAttachment> files = const []}) =>
    ChatMessage(
      id: 'm${i.toString().padLeft(4, '0')}',
      conversationId: 'c1',
      userId: 'u1',
      body: 'body $i',
      createdAt: '2026-09-10T00:00:0${i % 10}.000Z',
      attachments: files,
    );

ChatMessageAttachment _file(String url, String name, int size) =>
    ChatMessageAttachment(
      id: 'a-$name',
      messageId: '',
      fileName: name,
      fileUrl: url,
      contentType: 'image/jpeg',
      sizeBytes: size,
      uploadedBy: 'u1',
      createdAt: '2026-09-10T00:00:00.000Z',
    );

/// The fixtures are dated September 2026; the three-month window is
/// measured from here so they all fall inside it.
DateTime _fixtureNow() => DateTime.utc(2026, 9, 20);

void main() {
  late ChatLocalDb db;
  late Directory temp;

  setUp(() {
    db = ChatLocalDb.forTesting(NativeDatabase.memory());
    temp = Directory.systemTemp.createTempSync('history-transfer-test');
  });

  tearDown(() async {
    await db.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  /// A directory of its own: a finished transfer discards its snapshot, and
  /// pointing that at the same folder as the test's media would delete the
  /// files the assertions read back.
  HistoryTransferSnapshot snapshotIn(String name) => HistoryTransferSnapshot(
    Directory('${temp.path}/$name')..createSync(recursive: true),
  );

  Future<HistoryTransferManifest> readManifest(
    _FakeApi api,
    List<int> key,
  ) async => HistoryTransferManifest.fromJson(
    Map<String, dynamic>.from(
      jsonDecode(
            utf8.decode(
              await HistoryTransferCrypto.openManifest(
                transferKey: key,
                sealed: HistoryTransferCodec.bytesFromB64(
                  api.manifestCiphertext!,
                ),
              ),
            ),
          )
          as Map,
    ),
  );

  test('messages and real media bytes both transfer', () async {
    final store = ChatMessageStore(db);
    final blobs = AttachmentBlobStore(db);
    final api = _FakeApi();
    final key = Uint8List.fromList(List<int>.generate(32, (i) => i));

    // One attachment this phone still holds, and one it no longer does — the
    // case the whole feature exists for: the server let the file go and only
    // the phone has the bytes.
    final photo = File('${temp.path}/photo.jpg')
      ..writeAsBytesSync(List<int>.generate(9000, (i) => i % 256));
    const heldUrl = 'https://cdn.test/chat/c1/photo.jpg';
    const goneUrl = 'https://cdn.test/chat/c1/gone.jpg';
    await blobs.ensure(
      urlKey: attachmentUrlKey(heldUrl),
      remoteUrl: heldUrl,
      fileName: 'photo.jpg',
      contentType: 'image/jpeg',
      expectedBytes: 9000,
    );
    await blobs.markReady(attachmentUrlKey(heldUrl), photo.path, 9000);

    await store.saveAll([
      _msg(1, files: [_file(heldUrl, 'photo.jpg', 9000)]),
      _msg(2, files: [_file(goneUrl, 'gone.jpg', 4242)]),
      _msg(3),
    ]);

    final outcome =
        await HistoryTransferExporter(
          api: api,
          store: store,
          blobs: blobs,
          openSnapshot: (id) async => snapshotIn('t1'),
          clock: _fixtureNow,
        ).run(
          transferId: 't1',
          transferKey: key,
          deviceId: 'Pixel',
          conversations: const [],
        );

    expect(outcome.completed, isTrue);
    // The missing file is reported, never counted as sent. A transfer that
    // moved every message and lost a photo is not "everything transferred".
    expect(outcome.missingFiles, 1);
    expect(api.manifestChunks, outcome.chunks);

    final manifest = await readManifest(api, key);
    expect(manifest.messageCount, 3);
    expect(manifest.attachments.length, 2);
    final held = manifest.attachments.firstWhere((f) => f.remoteUrl == heldUrl);
    final gone = manifest.attachments.firstWhere((f) => f.remoteUrl == goneUrl);
    expect(gone.available, isFalse);
    expect(gone.firstChunk, -1);
    expect(held.available, isTrue);
    expect(held.sizeBytes, 9000);
    expect(held.sha256, sha256.convert(photo.readAsBytesSync()).toString());

    // The media chunk really carries the file, and only under its own index.
    final media = await HistoryTransferCrypto.openChunk(
      transferKey: key,
      index: held.firstChunk,
      sealed: api.objects[held.firstChunk]!,
    );
    expect(media, photo.readAsBytesSync());
    expect(held.firstChunk, greaterThanOrEqualTo(manifest.messageChunkCount));

    // The message stream decrypts as gzipped NDJSON with every row in it.
    final text = utf8.decode(
      gzip.decode(
        await HistoryTransferCrypto.openChunk(
          transferKey: key,
          index: 0,
          sealed: api.objects[0]!,
        ),
      ),
    );
    expect('m0001'.allMatches(text).length, 1);
    expect(text.contains('"t":"end"'), isTrue);
  });

  test('a resumed run never re-sends a chunk the server already has', () async {
    final store = ChatMessageStore(db);
    final api = _FakeApi()..settled.add(0);
    await store.saveAll([_msg(1), _msg(2)]);

    await HistoryTransferExporter(
      api: api,
      store: store,
      blobs: AttachmentBlobStore(db),
      openSnapshot: (id) async => snapshotIn('t2'),
      clock: _fixtureNow,
    ).run(
      transferId: 't2',
      transferKey: Uint8List(32),
      deviceId: 'Pixel',
      conversations: const [],
    );

    // Chunk 0 was reserved — that is how the source learns it is settled — but
    // never uploaded again. An uploaded chunk is frozen server-side, and the
    // destination may have read it already.
    expect(api.reserved, contains(0));
    expect(api.objects.containsKey(0), isFalse);
    expect(api.manifestChunks, isNotNull);
  });

  test('cancelling stops the upload and commits no manifest', () async {
    final store = ChatMessageStore(db);
    final api = _FakeApi();
    await store.saveAll([_msg(1)]);

    final outcome =
        await HistoryTransferExporter(
          api: api,
          store: store,
          blobs: AttachmentBlobStore(db),
          isCancelled: () => true,
          openSnapshot: (id) async => snapshotIn('t3'),
          clock: _fixtureNow,
        ).run(
          transferId: 't3',
          transferKey: Uint8List(32),
          deviceId: 'Pixel',
          conversations: const [],
        );

    expect(outcome.completed, isFalse);
    expect(api.manifestChunks, isNull);
    // The snapshot survives a cancel: the window is 24 hours and the run can
    // be resumed rather than rebuilt.
    expect(snapshotIn('t3').planFile.existsSync(), isTrue);
  });
}
