import 'dart:io';

import 'package:ababilx/features/attachments/data/local/attachment_blob_store.dart';
import 'package:ababilx/features/attachments/data/local/attachment_dedupe_store.dart';
import 'package:ababilx/features/attachments/data/local/attachment_ref_store.dart';
import 'package:ababilx/features/attachments/data/models/attachment_handle.dart';
import 'package:ababilx/features/attachments/data/models/attachment_url_key.dart';
import 'package:ababilx/features/attachments/services/attachment_cipher.dart';
import 'package:ababilx/features/attachments/services/attachment_content_hash.dart';
import 'package:ababilx/features/attachments/services/attachment_downloader.dart';
import 'package:ababilx/features/attachments/services/attachment_paths.dart';
import 'package:ababilx/features/attachments/services/attachment_queue.dart';
import 'package:ababilx/features/attachments/services/attachment_sweeper.dart';
import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/data/models/chat_attachment.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Two different R2 objects, identical bytes — the same photo sent by two
/// people, or re-uploaded. Disk should hold one copy, and deleting either
/// message must never pull the file out from under the other.
void main() {
  late Directory temp;
  late ChatLocalDb db;
  late AttachmentBlobStore blobs;
  late AttachmentDedupeStore dedupe;
  late AttachmentRefStore refs;
  late AttachmentPaths paths;
  late AttachmentQueue queue;
  late AttachmentSweeper sweeper;
  late HttpServer server;
  final bytes = [1, 2, 3, 4, 5, 6, 7, 8];

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('ababilx-dedupe-test-');
    db = ChatLocalDb.forTesting(NativeDatabase.memory());
    blobs = AttachmentBlobStore(db);
    dedupe = AttachmentDedupeStore(db);
    refs = AttachmentRefStore(db);
    paths = AttachmentPaths(rootDirectory: () async => temp);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.contentLength = bytes.length;
      request.response.add(bytes);
      await request.response.close();
    });
    queue = AttachmentQueue(
      blobs,
      dedupe,
      paths,
      AttachmentDownloader(Dio(), const PassthroughAttachmentCipher()),
    );
    sweeper = AttachmentSweeper(blobs, dedupe, refs, paths);
  });

  tearDown(() async {
    queue.dispose();
    await server.close(force: true);
    await db.close();
    await temp.delete(recursive: true);
  });

  ChatMessageAttachment attachmentAt(
    String id,
    String messageId,
    String path,
  ) => ChatMessageAttachment(
    id: id,
    messageId: messageId,
    fileName: 'photo.jpg',
    fileUrl: 'http://${server.address.host}:${server.port}$path',
    contentType: 'image/jpeg',
    sizeBytes: bytes.length,
    uploadedBy: 'user-1',
    createdAt: '',
  );

  test(
    'identical bytes at two different URLs share one file on disk',
    () async {
      final a = attachmentAt('att-a', 'msg-a', '/a.jpg');
      final b = attachmentAt('att-b', 'msg-b', '/b.jpg');
      await refs.indexAll([
        AttachmentRefEntry(
          attachmentId: a.id,
          urlKey: attachmentUrlKey(a.fileUrl),
          messageId: 'msg-a',
          conversationId: 'conversation-a',
        ),
        AttachmentRefEntry(
          attachmentId: b.id,
          urlKey: attachmentUrlKey(b.fileUrl),
          messageId: 'msg-b',
          conversationId: 'conversation-b',
        ),
      ]);

      // Sequential and awaited, deliberately: this test is about the dedupe
      // decision itself, not about racing it against the auto-download path
      // (covered by attachment_reopen_test.dart).
      await queue.enqueue(a, userInitiated: true);
      await queue.enqueue(b, userInitiated: true);

      final rowA = await blobs.read(attachmentUrlKey(a.fileUrl));
      final rowB = await blobs.read(attachmentUrlKey(b.fileUrl));
      expect(rowA!.transferState, AttachmentTransferState.ready.index);
      expect(rowB!.transferState, AttachmentTransferState.ready.index);
      expect(rowA.contentHash, isNotEmpty);
      expect(
        rowB.localPath,
        rowA.localPath,
        reason: 'the second download recognises the first\'s bytes',
      );

      // Only one physical file backs both rows.
      final onDisk = (await temp.list(recursive: true).toList())
          .whereType<File>()
          .where((f) => !f.path.endsWith('.part'));
      expect(onDisk, hasLength(1));

      // Deleting the first message's blob must not break the second's file —
      // the dedupe store's refcount is what stops that.
      await sweeper.onMessageDeleted('msg-a');
      expect(await blobs.read(attachmentUrlKey(a.fileUrl)), isNull);
      expect(File(rowB.localPath!).existsSync(), isTrue);
      expect(await blobs.isReady(attachmentUrlKey(b.fileUrl)), isTrue);

      // Now the only remaining reference is gone too — the file finally goes.
      await sweeper.onMessageDeleted('msg-b');
      expect(File(rowB.localPath!).existsSync(), isFalse);
    },
  );

  test('a crash between the DB commit and the redundant-file delete '
      'leaves the row valid and the leak reclaimable', () async {
    final a = attachmentAt('att-a', 'msg-a', '/a.jpg');
    final b = attachmentAt('att-b', 'msg-b', '/b.jpg');
    final urlKeyA = attachmentUrlKey(a.fileUrl);
    final urlKeyB = attachmentUrlKey(b.fileUrl);
    // Both rows are referenced by a live message — the orphan sweep that
    // `sweeper.sweep()` also runs must not mistake either for abandoned.
    // `orphanUrlKeys()` treats a ref as live only if its message still
    // exists in `cached_messages`, so both need a row there too.
    for (final id in ['msg-a', 'msg-b']) {
      await db.customStatement(
        'INSERT INTO cached_messages '
        '(id, conversation_id, created_at_ms, payload_json, search_text) '
        "VALUES ('$id', 'conversation-$id', 0, '{}', '')",
      );
    }
    await refs.indexAll([
      AttachmentRefEntry(
        attachmentId: a.id,
        urlKey: urlKeyA,
        messageId: 'msg-a',
        conversationId: 'conversation-a',
      ),
      AttachmentRefEntry(
        attachmentId: b.id,
        urlKey: urlKeyB,
        messageId: 'msg-b',
        conversationId: 'conversation-b',
      ),
    ]);
    final hash = await () async {
      final probe = await paths.fileFor(urlKeyA, 'photo.jpg', 'image/jpeg');
      await probe.writeAsBytes(bytes);
      final h = await hashFileContents(probe);
      await probe.delete();
      return h;
    }();

    // A already finished, uneventfully, at its own natural path.
    final fileA = await paths.fileFor(urlKeyA, 'photo.jpg', 'image/jpeg');
    await fileA.writeAsBytes(bytes);
    await blobs.ensure(
      urlKey: urlKeyA,
      remoteUrl: a.fileUrl,
      fileName: a.fileName,
      contentType: a.contentType,
      expectedBytes: bytes.length,
    );
    await blobs.markReady(urlKeyA, fileA.path, bytes.length, contentHash: hash);

    // B's own download finished too — its bytes are sitting at B's natural
    // path, identical to A's. This is the exact moment `_transfer` commits
    // the row to A's path and then, in the same breath, deletes this file —
    // simulate the process dying in between: the row is written, the
    // delete never runs.
    final fileB = await paths.fileFor(urlKeyB, 'photo.jpg', 'image/jpeg');
    await fileB.writeAsBytes(bytes);
    await blobs.ensure(
      urlKey: urlKeyB,
      remoteUrl: b.fileUrl,
      fileName: b.fileName,
      contentType: b.contentType,
      expectedBytes: bytes.length,
    );
    await blobs.markReady(urlKeyB, fileA.path, bytes.length, contentHash: hash);
    // (the delete of fileB that would normally follow never happens)

    // Immediately "post-crash": the row already points at valid bytes —
    // this is the whole point of committing the DB before the delete.
    final rowB = await blobs.read(urlKeyB);
    expect(rowB!.localPath, fileA.path);
    expect(await blobs.isReady(urlKeyB), isTrue);
    expect(File(rowB.localPath!).existsSync(), isTrue);
    // The leak: B's own file is still there, referenced by nothing.
    expect(fileB.existsSync(), isTrue);

    await sweeper.sweep();

    expect(fileB.existsSync(), isFalse, reason: 'the leaked copy is reclaimed');
    expect(
      fileA.existsSync(),
      isTrue,
      reason: 'the file everyone reads survives the sweep',
    );
    expect(await blobs.isReady(urlKeyB), isTrue);
    expect((await blobs.read(urlKeyB))!.localPath, fileA.path);
  });
}
