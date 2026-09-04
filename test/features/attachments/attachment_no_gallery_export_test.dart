import 'dart:io';

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
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A received photo stops in the app-private store.
///
/// It used to be copied into the public gallery the moment it finished, which
/// put every image in the chat history into the phone's photo app — and put a
/// second copy there after each reinstall, because the "already exported"
/// ledger lived in the app database the reinstall had just wiped while the
/// MediaStore rows survived. Signal's rule instead: nothing leaves the sandbox
/// until the user taps Save.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a finished download never writes to the public gallery', () async {
    // The test binding stubs every HttpClient out to a 400. This case needs a
    // real socket to the loopback server below, and a real method channel, so
    // it keeps the binding and drops only the HTTP override.
    final overrides = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = overrides);

    const channel = MethodChannel('com.ababilx.app/media_store');
    final mediaStoreCalls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          mediaStoreCalls.add(call.method);
          return '/storage/emulated/0/Pictures/AbabilXStorage/photo.jpg';
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final temp = await Directory.systemTemp.createTemp('ababilx-export-test-');
    final db = ChatLocalDb.forTesting(NativeDatabase.memory());
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.add([9, 8, 7, 6]);
      await request.response.close();
    });
    final blobs = AttachmentBlobStore(db);
    final queue = AttachmentQueue(
      blobs,
      AttachmentDedupeStore(db),
      AttachmentPaths(rootDirectory: () async => temp),
      AttachmentDownloader(Dio(), const PassthroughAttachmentCipher()),
    );

    final handle = await queue.enqueue(
      ChatMessageAttachment(
        id: 'attachment-1',
        messageId: 'message-1',
        fileName: 'photo.jpg',
        fileUrl: 'http://${server.address.host}:${server.port}/photo.jpg',
        contentType: 'image/jpeg',
        sizeBytes: 4,
        uploadedBy: 'user',
        createdAt: '',
      ),
      userInitiated: true,
    );
    expect(handle.state, AttachmentTransferState.ready);

    // The queue hands the export off with `unawaited`, so a regression would
    // land a tick after the handle settles rather than before it.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(mediaStoreCalls, isEmpty);

    final row = await blobs.read(handle.urlKey);
    expect(row?.exportedAtMs, isNull);
    expect(row?.exportedPath, isNull);

    queue.dispose();
    await server.close(force: true);
    await db.close();
    await temp.delete(recursive: true);
  });
}
