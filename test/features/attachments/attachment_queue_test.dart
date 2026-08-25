import 'dart:io';

import 'package:ababilx/features/attachments/data/local/attachment_blob_store.dart';
import 'package:ababilx/features/attachments/data/models/attachment_handle.dart';
import 'package:ababilx/features/attachments/services/attachment_cipher.dart';
import 'package:ababilx/features/attachments/services/attachment_downloader.dart';
import 'package:ababilx/features/attachments/services/attachment_paths.dart';
import 'package:ababilx/features/attachments/services/attachment_queue.dart';
import 'package:ababilx/features/attachments/services/attachment_semaphore.dart';
import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/data/models/chat_attachment.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('forwarded rows share one in-flight HTTP request', () async {
    final temp = await Directory.systemTemp.createTemp('ababilx-queue-test-');
    final db = ChatLocalDb.forTesting(NativeDatabase.memory());
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requests = 0;
    server.listen((request) async {
      requests++;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      request.response.add([1, 2, 3, 4]);
      await request.response.close();
    });
    final url = 'http://${server.address.host}:${server.port}/same.jpg';
    final attachment = ChatMessageAttachment(
      id: 'forward-1',
      messageId: 'message-1',
      fileName: 'same.jpg',
      fileUrl: url,
      contentType: 'image/jpeg',
      sizeBytes: 4,
      uploadedBy: 'user',
      createdAt: '',
    );
    final queue = AttachmentQueue(
      AttachmentBlobStore(db),
      AttachmentPaths(rootDirectory: () async => temp),
      AttachmentDownloader(Dio(), const PassthroughAttachmentCipher()),
    );

    final first = queue.enqueue(attachment, userInitiated: true);
    final second = queue.enqueue(attachment, userInitiated: true);
    expect(identical(first, second), isTrue);
    final handles = await Future.wait([first, second]);
    expect(requests, 1);
    expect(
      handles.every((handle) => handle.state == AttachmentTransferState.ready),
      isTrue,
    );

    queue.dispose();
    await server.close(force: true);
    await db.close();
    await temp.delete(recursive: true);
  });

  test(
    'user waiter overtakes automatic waiter without exceeding limit',
    () async {
      final gate = AttachmentSemaphore(1);
      final order = <String>[];
      await gate.acquire(userInitiated: false);
      final automatic = gate
          .acquire(userInitiated: false)
          .then((_) => order.add('auto'));
      final user = gate
          .acquire(userInitiated: true)
          .then((_) => order.add('user'));

      expect(gate.active, 1);
      gate.release();
      await user;
      expect(order, ['user']);
      gate.release();
      await automatic;
      expect(order, ['user', 'auto']);
      gate.release();
      expect(gate.active, 0);
    },
  );
}
