import 'dart:io';

import 'package:ababilx/features/attachments/auto_download/auto_download_gate.dart';
import 'package:ababilx/features/attachments/data/local/attachment_blob_store.dart';
import 'package:ababilx/features/attachments/data/local/attachment_dedupe_store.dart';
import 'package:ababilx/features/attachments/data/local/attachment_ref_store.dart';
import 'package:ababilx/features/attachments/data/models/attachment_handle.dart';
import 'package:ababilx/features/attachments/data/models/attachment_url_key.dart';
import 'package:ababilx/features/attachments/services/attachment_authority.dart';
import 'package:ababilx/features/attachments/services/attachment_cipher.dart';
import 'package:ababilx/features/attachments/services/attachment_downloader.dart';
import 'package:ababilx/features/attachments/services/attachment_intake.dart';
import 'package:ababilx/features/attachments/services/attachment_paths.dart';
import 'package:ababilx/features/attachments/services/attachment_queue.dart';
import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/data/models/chat_attachment.dart';
import 'package:ababilx/features/messages/data/models/chat_message.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// The headline promise: R2 is only the origin. Once an object is on the
/// device, reopening the chat must read the local file and never hit the
/// network again — and if that file disappears, the app must notice and offer
/// the download afresh rather than showing a broken tile.
void main() {
  late Directory temp;
  late ChatLocalDb db;
  late AttachmentBlobStore blobs;
  late AttachmentRefStore refs;
  late AttachmentQueue queue;
  late AttachmentPaths paths;
  late HttpServer server;
  var requests = 0;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('ababilx-reopen-test-');
    db = ChatLocalDb.forTesting(NativeDatabase.memory());
    blobs = AttachmentBlobStore(db);
    refs = AttachmentRefStore(db);
    paths = AttachmentPaths(rootDirectory: () async => temp);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    requests = 0;
    server.listen((request) async {
      requests++;
      request.response.contentLength = 4;
      request.response.add([1, 2, 3, 4]);
      await request.response.close();
    });
    queue = AttachmentQueue(
      blobs,
      AttachmentDedupeStore(db),
      paths,
      AttachmentDownloader(Dio(), const PassthroughAttachmentCipher()),
    );
  });

  tearDown(() async {
    queue.dispose();
    await server.close(force: true);
    await db.close();
    await temp.delete(recursive: true);
  });

  ChatMessageAttachment imageAt(String url) => ChatMessageAttachment(
    id: 'attachment-1',
    messageId: 'message-1',
    fileName: 'photo.jpg',
    fileUrl: url,
    contentType: 'image/jpeg',
    sizeBytes: 4,
    uploadedBy: 'user-1',
    createdAt: '',
  );

  ChatMessage messageWith(ChatMessageAttachment attachment) => ChatMessage(
    id: 'message-1',
    conversationId: 'conversation-1',
    userId: 'user-1',
    body: '',
    createdAt: DateTime.now().toIso8601String(),
    attachments: [attachment],
  );

  test('a second open of the same chat downloads nothing', () async {
    final attachment = imageAt(
      'http://${server.address.host}:${server.port}/photo.jpg',
    );
    final intake = AttachmentIntake(
      blobs,
      refs,
      queue,
      AutoDownloadGate.fixed(),
    );

    await intake.onMessage(messageWith(attachment));
    // The first pass auto-downloads (small image), so wait for it to settle.
    await queue.enqueue(attachment);
    expect(requests, 1);
    expect(await blobs.isReady(attachmentUrlKey(attachment.fileUrl)), isTrue);

    // Reopening the conversation replays the same messages through intake.
    await intake.onMessage(messageWith(attachment));
    await intake.onMessage(messageWith(attachment));
    expect(requests, 1, reason: 'a downloaded file is never fetched twice');
  });

  test('resolve serves the local file, not the remote URL', () async {
    final attachment = imageAt(
      'http://${server.address.host}:${server.port}/photo.jpg',
    );
    await queue.enqueue(attachment, userInitiated: true);
    final authority = AttachmentAuthority(blobs, queue);

    final handle = await authority.resolve(attachment);
    expect(handle.state, AttachmentTransferState.ready);
    expect(handle.localPath, isNotNull);
    expect(File(handle.localPath!).existsSync(), isTrue);
    expect(handle.localPath, isNot(contains('http')));
  });

  test('a file deleted off the device falls back to download', () async {
    final attachment = imageAt(
      'http://${server.address.host}:${server.port}/photo.jpg',
    );
    await queue.enqueue(attachment, userInitiated: true);
    final authority = AttachmentAuthority(blobs, queue);
    final ready = await authority.resolve(attachment);

    // The user cleared their gallery, or the OS reclaimed the sandbox.
    await File(ready.localPath!).delete();

    final after = await authority.resolve(attachment);
    expect(after.state, AttachmentTransferState.absent);
    expect(after.localPath, isNull);

    await queue.enqueue(attachment, userInitiated: true);
    expect(requests, 2, reason: 'the missing file is fetched again');
    expect((await authority.resolve(attachment)).isReady, isTrue);
  });

  test(
    'a transfer stuck mid-download after a process death is retried',
    () async {
      final attachment = imageAt(
        'http://${server.address.host}:${server.port}/photo.jpg',
      );
      final urlKey = attachmentUrlKey(attachment.fileUrl);
      // No job is running for this urlKey in this (fresh) queue instance —
      // exactly what a relaunch looks like: the in-memory job map starts
      // empty, but the DB row was left `downloading` by the process that died.
      await blobs.ensure(
        urlKey: urlKey,
        remoteUrl: attachment.fileUrl,
        fileName: attachment.fileName,
        contentType: attachment.contentType,
        expectedBytes: attachment.sizeBytes,
      );
      await blobs.setState(
        urlKey,
        AttachmentTransferState.downloading,
        receivedBytes: 1,
      );

      await AttachmentIntake(
        blobs,
        refs,
        queue,
        AutoDownloadGate.fixed(),
      ).onMessage(messageWith(attachment));
      await queue.enqueue(attachment);

      expect(requests, 1, reason: 'the stalled transfer restarts on its own');
      expect(await blobs.isReady(urlKey), isTrue);
    },
  );

  test('a permanently failed attachment is never retried', () async {
    final attachment = imageAt('http://${server.address.host}:1/gone.jpg');
    final urlKey = attachmentUrlKey(attachment.fileUrl);
    await blobs.ensure(
      urlKey: urlKey,
      remoteUrl: attachment.fileUrl,
      fileName: attachment.fileName,
      contentType: attachment.contentType,
      expectedBytes: attachment.sizeBytes,
    );
    // Stands in for the outcome of an earlier 404/410 — the object is gone
    // for good, so intake must not keep spending network on it.
    await blobs.setState(
      urlKey,
      AttachmentTransferState.permanentlyFailed,
      lastError: 'This file is no longer available',
    );

    final intake = AttachmentIntake(
      blobs,
      refs,
      queue,
      AutoDownloadGate.fixed(),
    );
    await intake.onMessage(messageWith(attachment));
    await intake.onMessage(messageWith(attachment));

    expect(requests, 0, reason: 'a permanent failure is never re-enqueued');
  });

  test('a locked attachment never touches the network or the store', () async {
    final locked = ChatMessageAttachment(
      id: 'attachment-2',
      messageId: 'message-2',
      fileName: 'contract.pdf',
      fileUrl: '',
      contentType: 'application/pdf',
      sizeBytes: 0,
      uploadedBy: 'user-1',
      createdAt: '',
      locked: true,
    );
    final authority = AttachmentAuthority(blobs, queue);

    final handle = await authority.resolve(locked);
    expect(handle.state, AttachmentTransferState.locked);
    await AttachmentIntake(
      blobs,
      refs,
      queue,
      AutoDownloadGate.fixed(),
    ).onMessage(messageWith(locked));
    expect(requests, 0);
  });
}
