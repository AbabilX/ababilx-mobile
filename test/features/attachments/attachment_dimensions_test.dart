import 'dart:io';
import 'dart:typed_data';

import 'package:ababilx/features/attachments/data/local/attachment_blob_store.dart';
import 'package:ababilx/features/attachments/data/local/attachment_dedupe_store.dart';
import 'package:ababilx/features/attachments/data/models/attachment_url_key.dart';
import 'package:ababilx/features/attachments/data/models/media_dimensions.dart';
import 'package:ababilx/features/attachments/services/attachment_adopter.dart';
import 'package:ababilx/features/attachments/services/attachment_authority.dart';
import 'package:ababilx/features/attachments/services/attachment_cipher.dart';
import 'package:ababilx/features/attachments/services/attachment_dimension_reader.dart';
import 'package:ababilx/features/attachments/services/attachment_downloader.dart';
import 'package:ababilx/features/attachments/services/attachment_handle_memory.dart';
import 'package:ababilx/features/attachments/services/attachment_paths.dart';
import 'package:ababilx/features/attachments/services/attachment_queue.dart';
import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/data/models/chat_attachment.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// A photo's size is measured once, when its bytes land, and kept — so a
/// timeline tile can mount at its final height instead of learning it from a
/// decode and pushing the rows above it.
void main() {
  late Directory temp;
  late ChatLocalDb db;
  late AttachmentHandleMemory memory;
  late AttachmentBlobStore blobs;
  late AttachmentQueue queue;
  late AttachmentDimensionReader reader;
  late AttachmentAdopter adopter;
  late AttachmentAuthority authority;
  var measured = 0;

  const url = 'https://cdn.example.com/chat/c1/photo.jpg';
  const attachment = ChatMessageAttachment(
    id: 'a1',
    messageId: 'm1',
    fileName: 'photo.jpg',
    fileUrl: url,
    contentType: 'image/jpeg',
    sizeBytes: 8,
    uploadedBy: 'u1',
    createdAt: '',
  );
  final key = attachmentUrlKey(url);

  setUp(() async {
    measured = 0;
    temp = await Directory.systemTemp.createTemp('ababilx-dims-test-');
    db = ChatLocalDb.forTesting(NativeDatabase.memory());
    memory = AttachmentHandleMemory();
    blobs = AttachmentBlobStore(db, onForget: memory.forget);
    reader = AttachmentDimensionReader(
      blobs,
      memory,
      measure: (path, {required video}) async {
        measured++;
        return const MediaDimensions(1200, 600);
      },
    );
    final dedupe = AttachmentDedupeStore(db);
    final paths = AttachmentPaths(rootDirectory: () async => temp);
    queue = AttachmentQueue(
      blobs,
      dedupe,
      paths,
      AttachmentDownloader(Dio(), const PassthroughAttachmentCipher()),
      dimensions: reader,
    );
    adopter = AttachmentAdopter(
      blobs,
      dedupe,
      paths,
      queue,
      dimensions: reader,
    );
    authority = AttachmentAuthority(
      blobs,
      queue,
      memory: memory,
      dimensions: reader,
    );
  });

  tearDown(() async {
    authority.dispose();
    queue.dispose();
    await db.close();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  Future<void> adopt() => adopter.adoptBytes(
    fileUrl: url,
    fileName: 'photo.jpg',
    contentType: 'image/jpeg',
    bytes: Uint8List.fromList(List.filled(8, 7)),
  );

  test('an adopted photo is announced already sized, and stored', () async {
    final announced = queue.events.first;
    await adopt();

    expect((await announced).dimensions, const MediaDimensions(1200, 600));
    final row = await blobs.read(key);
    expect((row!.mediaWidth, row.mediaHeight), (1200, 600));
    expect(memory.dimensionsOf(key), const MediaDimensions(1200, 600));
  });

  test('resolve reads the stored size without measuring again', () async {
    await adopt();
    final fresh = AttachmentAuthority(
      blobs,
      queue,
      memory: AttachmentHandleMemory(),
      dimensions: AttachmentDimensionReader(
        blobs,
        AttachmentHandleMemory(),
        measure: (path, {required video}) async => fail('measured twice'),
      ),
    );
    final handle = await fresh.resolve(attachment);
    expect(handle.isReady, isTrue);
    expect(handle.dimensions, const MediaDimensions(1200, 600));
    fresh.dispose();
  });

  test('a file downloaded before sizes existed is measured once', () async {
    await adopt();
    await db.customStatement(
      'UPDATE attachment_blobs SET media_width = NULL, media_height = NULL',
    );
    memory.clear();
    measured = 0;

    final both = await Future.wait([
      authority.resolve(attachment),
      authority.resolve(attachment),
    ]);
    expect(both.map((h) => h.dimensions), everyElement(isNotNull));
    expect(measured, 1, reason: 'two bubbles, one measurement');
  });

  test('eviction forgets the path but keeps the shape', () async {
    await adopt();
    await Future<void>.delayed(Duration.zero); // queue events arrive async
    expect(memory.handleOf(key)?.isReady, isTrue);

    await blobs.markAbsent(key);

    expect(memory.handleOf(key), isNull, reason: 'never offer a gone file');
    expect(memory.dimensionsOf(key), const MediaDimensions(1200, 600));
    final absent = await authority.resolve(attachment);
    expect(absent.isReady, isFalse);
    expect(absent.dimensions, const MediaDimensions(1200, 600));
  });

  test('warm loads recorded sizes before any row asks', () async {
    await adopt();
    memory.clear();

    await reader.warm(const [attachment]);

    expect(memory.dimensionsOf(key), const MediaDimensions(1200, 600));
  });

  test('V7 to V8 adds the size columns and keeps rows', () async {
    await db.customStatement('DROP TABLE attachment_blobs');
    await db.customStatement(
      'CREATE TABLE attachment_blobs (url_key TEXT NOT NULL PRIMARY KEY, '
      'transfer_state INTEGER NOT NULL DEFAULT 0, local_path TEXT)',
    );
    await db.customStatement(
      "INSERT INTO attachment_blobs (url_key, transfer_state) VALUES ('k', 3)",
    );

    await db.migration.onUpgrade(db.createMigrator(), 7, 8);

    final columns = await db
        .customSelect('PRAGMA table_info(attachment_blobs)')
        .get();
    expect(
      columns.map((row) => row.read<String>('name')),
      containsAll(['media_width', 'media_height']),
    );
    final kept = await db
        .customSelect('SELECT url_key FROM attachment_blobs')
        .getSingle();
    expect(kept.read<String>('url_key'), 'k');
  });

  test(
    'a device below V5 jumping to V8 does not add the columns twice',
    () async {
      await db.customStatement('DROP TABLE attachment_refs');
      await db.customStatement('DROP TABLE attachment_blobs');

      await db.migration.onUpgrade(db.createMigrator(), 4, 8);

      final columns = await db
          .customSelect('PRAGMA table_info(attachment_blobs)')
          .get();
      expect(
        columns.map((row) => row.read<String>('name')),
        containsAll(['media_width', 'media_height']),
      );
    },
  );
}
