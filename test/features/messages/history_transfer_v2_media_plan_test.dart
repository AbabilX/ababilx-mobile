import 'dart:io';

import 'package:ababilx/features/attachments/data/local/attachment_blob_store.dart';
import 'package:ababilx/features/attachments/data/models/attachment_url_key.dart';
import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/data/models/chat_attachment.dart';
import 'package:ababilx/features/messages/history-transfer/v2/v2_media_plan.dart';
import 'package:ababilx/features/messages/history-transfer/v2/v2_media_source.dart';
import 'package:ababilx/features/messages/history-transfer/v2/v2_plan.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessageAttachment _att(String url, int size) => ChatMessageAttachment(
  id: url,
  messageId: '',
  fileName: 'f',
  fileUrl: url,
  contentType: 'video/mp4',
  sizeBytes: size,
  uploadedBy: 'u',
  createdAt: '2023-01-01T00:00:00Z',
);

void main() {
  late ChatLocalDb db;
  late Directory temp;
  setUp(() {
    db = ChatLocalDb.forTesting(NativeDatabase.memory());
    temp = Directory.systemTemp.createTempSync('v2-media-plan');
  });
  tearDown(() async {
    await db.close();
    temp.deleteSync(recursive: true);
  });

  Future<void> hold(AttachmentBlobStore blobs, String url, int size) async {
    final file = File('${temp.path}/${url.hashCode}')
      ..writeAsBytesSync(List<int>.generate(size, (i) => i % 251));
    await blobs.ensure(
      urlKey: attachmentUrlKey(url),
      remoteUrl: url,
      fileName: 'f',
      contentType: 'video/mp4',
      expectedBytes: size,
    );
    await blobs.markReady(attachmentUrlKey(url), file.path, size);
  }

  test('a file longer than a batch continues as the next segment', () async {
    final blobs = AttachmentBlobStore(db);
    await hold(blobs, 'https://cdn/a', 700);
    await hold(blobs, 'https://cdn/big', 2500);
    await hold(blobs, 'https://cdn/empty', 0);
    final planned = await V2MediaPlanner(blobs: blobs, batchPlainBytes: 1000)
        .plan([
          _att('https://cdn/a', 700),
          _att('https://cdn/big', 2500),
          _att('https://cdn/empty', 0),
        ], 3);
    final big = planned.files.firstWhere(
      (f) => f.urlKey == attachmentUrlKey('https://cdn/big'),
    );
    expect(big.segments.map((s) => (s.batch, s.length)).toList(), [
      (3, 300),
      (4, 1000),
      (5, 1000),
      (6, 200),
    ]);
    expect(big.segments.every((s) => s.segs == 4), isTrue);
    expect(planned.batches.map((b) => b.batch).toList(), [3, 4, 5, 6]);
    final empty = planned.files.firstWhere(
      (f) => f.urlKey == attachmentUrlKey('https://cdn/empty'),
    );
    expect(empty.status, 'available');
    expect(empty.segments.single.length, 0);

    // The stream of batch 3 is file a then the head of big, byte for byte.
    final plan = V2Plan(
      transferId: 't',
      createdAtMs: 0,
      messageCount: 0,
      conversationCount: 0,
      batches: planned.batches,
      files: planned.files,
    );
    final bytes = await V2MediaSource(plan).plaintext(planned.batches.first, 0);
    expect(bytes.length, 1000);
    expect(bytes.sublist(0, 700), List<int>.generate(700, (i) => i % 251));
    expect(bytes.sublist(700), List<int>.generate(300, (i) => i % 251));
  });

  test('a file the browser already holds is not planned at all', () async {
    final blobs = AttachmentBlobStore(db);
    await hold(blobs, 'https://cdn/kept', 50);
    final first = await V2MediaPlanner(
      blobs: blobs,
    ).plan([_att('https://cdn/kept', 50)], 1);
    final kept = first.files.single;
    final second = await V2MediaPlanner(
      blobs: blobs,
      held: [(urlKey: kept.urlKey, sha256: kept.sha256, size: kept.size)],
    ).plan([_att('https://cdn/kept', 50)], 1);
    expect(second.files, isEmpty);
    expect(second.batches, isEmpty);
  });
}
