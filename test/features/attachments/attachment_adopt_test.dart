import 'dart:io';
import 'dart:typed_data';

import 'package:ababilx/features/attachments/data/local/attachment_blob_store.dart';
import 'package:ababilx/features/attachments/data/local/attachment_dedupe_store.dart';
import 'package:ababilx/features/attachments/data/models/attachment_handle.dart';
import 'package:ababilx/features/attachments/services/attachment_adopter.dart';
import 'package:ababilx/features/attachments/services/attachment_authority.dart';
import 'package:ababilx/features/attachments/services/attachment_cipher.dart';
import 'package:ababilx/features/attachments/services/attachment_downloader.dart';
import 'package:ababilx/features/attachments/services/attachment_paths.dart';
import 'package:ababilx/features/attachments/services/attachment_queue.dart';
import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/data/models/chat_attachment.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// The sender already holds the bytes. Adoption is what stops the app asking
/// them to download their own photo back from R2.
void main() {
  late Directory temp;
  late ChatLocalDb db;
  late AttachmentBlobStore blobs;
  late AttachmentQueue queue;
  late AttachmentAdopter adopter;
  late AttachmentAuthority authority;

  const url = 'https://cdn.example.com/chat/c1/photo.jpg';
  final attachment = ChatMessageAttachment(
    id: 'a1',
    messageId: 'm1',
    fileName: 'photo.jpg',
    fileUrl: url,
    contentType: 'image/jpeg',
    sizeBytes: 8,
    uploadedBy: 'u1',
    createdAt: '',
  );

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('ababilx-adopt-test-');
    db = ChatLocalDb.forTesting(NativeDatabase.memory());
    blobs = AttachmentBlobStore(db);
    final dedupe = AttachmentDedupeStore(db);
    final paths = AttachmentPaths(rootDirectory: () async => temp);
    queue = AttachmentQueue(
      blobs,
      dedupe,
      paths,
      AttachmentDownloader(Dio(), const PassthroughAttachmentCipher()),
    );
    adopter = AttachmentAdopter(blobs, dedupe, paths, queue);
    authority = AttachmentAuthority(blobs, queue);
  });

  tearDown(() async {
    queue.dispose();
    await db.close();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('an uploaded file resolves ready without any download', () async {
    final source = File('${temp.path}/picked.jpg')
      ..writeAsBytesSync([1, 2, 3, 4, 5, 6, 7, 8]);

    expect(
      (await authority.resolve(attachment)).state,
      AttachmentTransferState.absent,
    );

    await adopter.adoptFile(
      fileUrl: url,
      fileName: 'photo.jpg',
      contentType: 'image/jpeg',
      source: source,
    );

    final handle = await authority.resolve(attachment);
    expect(handle.state, AttachmentTransferState.ready);
    expect(File(handle.localPath!).readAsBytesSync(), source.readAsBytesSync());
    // The copy lives in the attachment store, not wherever the picker left it.
    expect(handle.localPath, isNot(source.path));
  });

  test('bytes with no path are adopted too', () async {
    await adopter.adoptBytes(
      fileUrl: url,
      fileName: 'photo.jpg',
      contentType: 'image/jpeg',
      bytes: Uint8List.fromList([9, 9, 9]),
    );
    final handle = await authority.resolve(attachment);
    expect(handle.state, AttachmentTransferState.ready);
    expect(handle.totalBytes, 3);
  });

  test('adoption announces the handle so a gate on screen swaps', () async {
    final seen = <AttachmentHandle>[];
    final sub = queue.events.listen(seen.add);
    await adopter.adoptBytes(
      fileUrl: url,
      fileName: 'photo.jpg',
      contentType: 'image/jpeg',
      bytes: Uint8List.fromList([1, 2]),
    );
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(seen.single.state, AttachmentTransferState.ready);
  });

  test('adopting twice keeps the first copy', () async {
    await adopter.adoptBytes(
      fileUrl: url,
      fileName: 'photo.jpg',
      contentType: 'image/jpeg',
      bytes: Uint8List.fromList([1, 2, 3]),
    );
    final first = (await authority.resolve(attachment)).localPath;
    await adopter.adoptBytes(
      fileUrl: url,
      fileName: 'photo.jpg',
      contentType: 'image/jpeg',
      bytes: Uint8List.fromList([4, 5, 6, 7]),
    );
    final second = await authority.resolve(attachment);
    expect(second.localPath, first);
    expect(second.totalBytes, 3);
  });
}
