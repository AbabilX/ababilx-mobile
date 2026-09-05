import 'dart:io';

import 'package:ababilx/features/attachments/data/local/attachment_blob_store.dart';
import 'package:ababilx/features/attachments/data/local/attachment_dedupe_store.dart';
import 'package:ababilx/features/attachments/data/local/attachment_ref_store.dart';
import 'package:ababilx/features/attachments/storage/storage_manager.dart';
import 'package:ababilx/features/attachments/storage/storage_usage_query.dart';
import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// A real database, real files on a temp directory, and one helper for filing
/// a finished download into both — everything the Manage-storage tests need
/// and nothing they have to mock.
class StorageFixture {
  late Directory temp;
  late ChatLocalDb db;
  late AttachmentBlobStore blobs;
  late AttachmentDedupeStore dedupe;
  late AttachmentRefStore refs;
  late StorageUsageQuery query;
  late StorageManager manager;

  Future<void> setUp() async {
    temp = await Directory.systemTemp.createTemp('ababilx-storage-test-');
    db = ChatLocalDb.forTesting(NativeDatabase.memory());
    blobs = AttachmentBlobStore(db);
    dedupe = AttachmentDedupeStore(db);
    refs = AttachmentRefStore(db);
    query = StorageUsageQuery(db);
    manager = StorageManager(blobs, dedupe, query);
  }

  Future<void> tearDown() async {
    await db.close();
    if (await temp.exists()) await temp.delete(recursive: true);
  }

  /// A ready blob backed by a real file of [bytes] length. [sharedPath] makes
  /// two rows point at one file, the way content-hash dedupe does.
  Future<File> store(
    String urlKey, {
    required String fileName,
    required String contentType,
    required int bytes,
    String conversationId = 'c1',
    String? sharedPath,
  }) async {
    await blobs.ensure(
      urlKey: urlKey,
      remoteUrl: 'https://cdn.example.com/$urlKey',
      fileName: fileName,
      contentType: contentType,
      expectedBytes: bytes,
    );
    final file = File('${temp.path}/${sharedPath ?? urlKey}');
    if (!await file.exists()) await file.writeAsBytes(List.filled(bytes, 0));
    await blobs.markReady(urlKey, file.path, bytes);
    await refs.indexAll([
      AttachmentRefEntry(
        attachmentId: 'a-$urlKey',
        urlKey: urlKey,
        messageId: 'm-$urlKey',
        conversationId: conversationId,
      ),
    ]);
    return file;
  }
}

/// Installs a fixture for the enclosing group.
StorageFixture useStorageFixture() {
  final fixture = StorageFixture();
  setUp(fixture.setUp);
  tearDown(fixture.tearDown);
  return fixture;
}
