import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ababilx/features/attachments/data/local/attachment_blob_store.dart';
import 'package:ababilx/features/attachments/data/models/attachment_url_key.dart';
import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/data/local/chat_message_store.dart';
import 'package:ababilx/features/messages/data/models/chat_attachment.dart';
import 'package:ababilx/features/messages/data/models/chat_message.dart';
import 'package:ababilx/features/messages/history-transfer/v2/v2_crypto.dart';
import 'package:ababilx/features/messages/history-transfer/v2/v2_exporter.dart';
import 'package:ababilx/features/messages/history-transfer/v2/v2_store.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'history_transfer_v2_relay_fake.dart';

class _Keys implements V2KeyVault {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String id) async => values[id];
  @override
  Future<void> write(String id, String value) async => values[id] = value;
  @override
  Future<void> delete(String id) async => values.remove(id);
}

ChatMessage _msg(int i, {List<ChatMessageAttachment> files = const []}) =>
    ChatMessage(
      id: 'm$i',
      conversationId: 'c1',
      userId: 'u1',
      userName: 'Alice',
      body: 'body $i',
      createdAt: '2023-01-0${i}T00:00:00.000Z',
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
      createdAt: '2023-01-01T00:00:00.000Z',
    );

void main() {
  late ChatLocalDb db;
  late Directory temp;
  final key = Uint8List.fromList(List<int>.generate(32, (i) => i));
  const id = '3f0c9a1e-7b2d-4c55-9e1a-2b6f0d4c8a17';

  setUp(() {
    db = ChatLocalDb.forTesting(NativeDatabase.memory());
    temp = Directory.systemTemp.createTempSync('history-transfer-v2');
  });
  tearDown(() async {
    await db.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Future<V2Store> storeFor(String name) async => V2Store(
    Directory('${temp.path}/$name')..createSync(recursive: true),
    keys: _Keys(),
  );

  Future<String> heldPhoto(
    AttachmentBlobStore blobs,
    String url,
    int size,
  ) async {
    final photo = File('${temp.path}/${url.hashCode}.jpg')
      ..writeAsBytesSync(List<int>.generate(size, (i) => (i * 7) % 256));
    await blobs.ensure(
      urlKey: attachmentUrlKey(url),
      remoteUrl: url,
      fileName: 'p.jpg',
      contentType: 'image/jpeg',
      expectedBytes: size,
    );
    await blobs.markReady(attachmentUrlKey(url), photo.path, size);
    return photo.path;
  }

  test(
    'messages batch first, media after, and the browser can open every piece',
    () async {
      final messages = ChatMessageStore(db);
      final blobs = AttachmentBlobStore(db);
      const held = 'https://cdn.test/chat/c1/held.jpg';
      const gone = 'https://cdn.test/chat/c1/gone.jpg';
      final path = await heldPhoto(blobs, held, 9000);
      await messages.saveAll([
        _msg(1, files: [_file(held, 'held.jpg', 9000)]),
        _msg(2, files: [_file(gone, 'gone.jpg', 4242)]),
        _msg(3),
      ]);
      final relay = FakeRelay(id, key);

      final outcome = await HistoryTransferV2Exporter(
        api: relay,
        messages: messages,
        blobs: blobs,
        conversations: const [],
        openStore: (_) => storeFor('a'),
        pollEvery: Duration.zero,
        destinationInventoryWait: Duration.zero,
      ).run(transferId: id, transferKey: key);

      expect(outcome.completed, isTrue);
      expect(outcome.filesMissing, 1);
      expect(relay.kinds, ['messages', 'media']);
      expect(relay.finals, [false, true]);
      expect(relay.sealLast, 1);

      final text = utf8.decode(gzip.decode(await relay.stream(0, 'messages')));
      expect(RegExp('"t":"msg"').allMatches(text).length, 3);
      expect(text.indexOf('"t":"conv"') < text.indexOf('"t":"msg"'), isTrue);
      expect(text.trim().split('\n').last, contains('"t":"end"'));

      final mediaDescriptor = await relay.descriptor(1);
      final files = (mediaDescriptor['files'] as List).cast<Map>();
      final entry = files.firstWhere((f) => f['status'] == 'available');
      final missing = files.firstWhere((f) => f['status'] == 'missing');
      expect(missing['url_key'], attachmentUrlKey(gone));
      final stream = await relay.stream(1, 'media');
      final start = entry['stream_offset'] as int;
      final bytes = stream.sublist(start, start + (entry['length'] as int));
      expect(bytes, File(path).readAsBytesSync());
      expect(entry['seg_sha256'], sha256.convert(bytes).toString());

      final seal = await relay.openSeal();
      expect(seal['last_batch'], 1);
      expect(seal['files_missing'], 1);
    },
  );

  test('a resumed run never re-uploads a settled chunk', () async {
    final messages = ChatMessageStore(db);
    await messages.saveAll([_msg(1), _msg(2)]);
    final relay = FakeRelay(id, key)..settleOnReserve.add('0/0');
    await HistoryTransferV2Exporter(
      api: relay,
      messages: messages,
      blobs: AttachmentBlobStore(db),
      conversations: const [],
      openStore: (_) => storeFor('b'),
      pollEvery: Duration.zero,
      destinationInventoryWait: Duration.zero,
    ).run(transferId: id, transferKey: key);
    expect(relay.puts.contains('0/0'), isFalse);
  });

  test(
    'a file that vanishes after planning is sent as omitted, never skipped',
    () async {
      final messages = ChatMessageStore(db);
      final blobs = AttachmentBlobStore(db);
      const url = 'https://cdn.test/chat/c1/vanish.jpg';
      final path = await heldPhoto(blobs, url, 5000);
      await messages.saveAll([
        _msg(1, files: [_file(url, 'v.jpg', 5000)]),
      ]);
      final relay = FakeRelay(id, key)
        ..beforeFirstMediaReserve = () => File(path).deleteSync();
      final outcome = await HistoryTransferV2Exporter(
        api: relay,
        messages: messages,
        blobs: blobs,
        conversations: const [],
        openStore: (_) => storeFor('c'),
        pollEvery: Duration.zero,
        destinationInventoryWait: Duration.zero,
      ).run(transferId: id, transferKey: key);
      expect(outcome.completed, isTrue);
      expect(outcome.filesOmitted, 1);
      // The index was still uploaded (zeros), so the batch could finalize.
      expect(relay.puts.contains('1/0'), isTrue);
      final files = ((await relay.descriptor(1))['files'] as List).cast<Map>();
      expect(files.single['status'], 'omitted');
    },
  );

  test('pages bind their count: a dropped page fails every page', () async {
    final sealed = await HistoryTransferV2Crypto.seal(
      key,
      HistoryTransferV2Crypto.pageAad(id, 0, 0, 2),
      utf8.encode('{"a":'),
    );
    expect(
      () => HistoryTransferV2Crypto.open(
        key,
        HistoryTransferV2Crypto.pageAad(id, 0, 0, 1),
        sealed,
      ),
      throwsA(anything),
    );
  });

  test(
    'lost inventory and seal responses reuse persisted ciphertext',
    () async {
      final messages = ChatMessageStore(db);
      await messages.saveAll([_msg(1)]);
      final relay = FakeRelay(id, key)
        ..failInventoryResponseOnce = true
        ..failSealResponseOnce = true;
      final directory = 'durable-retries';
      HistoryTransferV2Exporter exporter() => HistoryTransferV2Exporter(
        api: relay,
        messages: messages,
        blobs: AttachmentBlobStore(db),
        conversations: const [],
        openStore: (_) => storeFor(directory),
        pollEvery: Duration.zero,
        destinationInventoryWait: Duration.zero,
      );

      await expectLater(
        exporter().run(transferId: id, transferKey: key),
        throwsStateError,
      );
      await expectLater(
        exporter().run(transferId: id, transferKey: key),
        throwsStateError,
      );
      final outcome = await exporter().run(transferId: id, transferKey: key);
      expect(outcome.completed, isTrue);
      expect(relay.inventoryAttempts.length, 2);
      expect(relay.inventoryAttempts.toSet().length, 1);
      expect(relay.sealAttempts.length, 2);
      expect(relay.sealAttempts.toSet().length, 1);
    },
  );
}
