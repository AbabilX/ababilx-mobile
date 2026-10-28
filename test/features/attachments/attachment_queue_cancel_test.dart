import 'dart:async';
import 'dart:io';
import 'package:ababilx/features/attachments/data/local/attachment_blob_store.dart';
import 'package:ababilx/features/attachments/data/local/attachment_dedupe_store.dart';
import 'package:ababilx/features/attachments/data/models/attachment_handle.dart';
import 'package:ababilx/features/attachments/services/attachment_cipher.dart';
import 'package:ababilx/features/attachments/services/attachment_downloader.dart';
import 'package:ababilx/features/attachments/services/attachment_paths.dart';
import 'package:ababilx/features/attachments/services/attachment_queue.dart';
import 'package:ababilx/features/attachments/services/attachment_semaphore.dart';
import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/data/models/chat_attachment.dart';
import 'package:dio/dio.dart';
import 'package:ababilx/features/attachments/data/models/attachment_url_key.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late ChatLocalDb db;
  late HttpServer server;
  late AttachmentQueue queue;
  late Completer<void> started;
  late List<String> requests;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('queue-cancel-');
    db = ChatLocalDb.forTesting(NativeDatabase.memory());
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    started = Completer<void>();
    requests = [];
    server.listen((r) async {
      requests.add(r.uri.path);
      if (!started.isCompleted) started.complete();
      if (r.uri.path == '/fail') {
        r.response.statusCode = 500;
        await r.response.close();
      }
      // Other requests remain pending until cancelled.
    });
    queue = AttachmentQueue(
      AttachmentBlobStore(db),
      AttachmentDedupeStore(db),
      AttachmentPaths(rootDirectory: () async => dir),
      AttachmentDownloader(Dio(), const PassthroughAttachmentCipher()),
      semaphore: AttachmentSemaphore(1),
    );
  });
  tearDown(() async {
    queue.dispose();
    await server.close(force: true);
    await db.close();
    await dir.delete(recursive: true);
  });
  ChatMessageAttachment item(String name) => ChatMessageAttachment(
    id: name,
    messageId: name,
    fileName: name,
    fileUrl: 'http://127.0.0.1:${server.port}/$name',
    contentType: 'application/octet-stream',
    sizeBytes: 3,
    uploadedBy: 'u',
    createdAt: '',
  );

  test(
    'cancelAll cancels running and waiting jobs and refuses later work',
    () async {
      final first = queue.enqueue(item('first'));
      await started.future;
      final second = queue.enqueue(item('second'));
      await queue.cancelAll().timeout(const Duration(seconds: 2));
      expect((await first).state, AttachmentTransferState.absent);
      expect((await second).state, AttachmentTransferState.absent);
      expect(
        (await queue.enqueue(item('third'))).state,
        AttachmentTransferState.absent,
      );
      expect(requests, ['/first']);
      expect(
        queue.isRunning(attachmentUrlKey(item('second').fileUrl)),
        isFalse,
      );
    },
  );
  test(
    'cancelling a queued job settles without waiting for the active request',
    () async {
      final first = queue.enqueue(item('first'));
      await started.future;
      final secondItem = item('second');
      final second = queue.enqueue(secondItem);
      queue.cancel(attachmentUrlKey(secondItem.fileUrl));
      expect(
        (await second.timeout(const Duration(seconds: 2))).state,
        AttachmentTransferState.absent,
      );
      expect(requests, ['/first']);
      await queue.cancelAll();
      await first;
    },
  );
  test('cancellation during retry delay prevents another attempt', () async {
    final pending = queue.enqueue(item('fail'), userInitiated: true);
    await started.future;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await queue.cancelAll().timeout(const Duration(milliseconds: 500));
    expect((await pending).state, AttachmentTransferState.absent);
    expect(requests, ['/fail']);
  });
  test(
    'dispose settles waiting work without starting a new transfer',
    () async {
      final first = queue.enqueue(item('first'));
      await started.future;
      final second = queue.enqueue(item('second'));
      queue.dispose();
      await Future.wait([first, second]).timeout(const Duration(seconds: 2));
      expect(requests, ['/first']);
    },
  );
}
