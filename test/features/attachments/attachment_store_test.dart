import 'package:ababilx/features/attachments/data/local/attachment_blob_store.dart';
import 'package:ababilx/features/attachments/data/local/attachment_ref_store.dart';
import 'package:ababilx/features/attachments/data/models/attachment_handle.dart';
import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ChatLocalDb db;
  late AttachmentBlobStore blobs;
  late AttachmentRefStore refs;

  setUp(() {
    db = ChatLocalDb.forTesting(NativeDatabase.memory());
    blobs = AttachmentBlobStore(db);
    refs = AttachmentRefStore(db);
  });
  tearDown(() => db.close());

  test('ready blob persists its canonical path and bytes', () async {
    await blobs.ensure(
      urlKey: 'key',
      remoteUrl: 'https://example.com/a.jpg',
      fileName: 'a.jpg',
      contentType: 'image/jpeg',
      expectedBytes: 12,
    );
    await blobs.markReady('key', '/private/a.jpg', 12);

    final row = await blobs.read('key');
    expect(row?.transferState, AttachmentTransferState.ready.index);
    expect(row?.localPath, '/private/a.jpg');
    expect(row?.receivedBytes, 12);
  });

  test('one forwarded reference keeps a shared blob alive', () async {
    await refs.indexAll(const [
      AttachmentRefEntry(
        attachmentId: 'a1',
        urlKey: 'shared',
        messageId: 'm1',
        conversationId: 'c1',
      ),
      AttachmentRefEntry(
        attachmentId: 'a2',
        urlKey: 'shared',
        messageId: 'm2',
        conversationId: 'c2',
      ),
    ]);

    expect(await refs.removeForMessage('m1'), isEmpty);
    expect(await refs.refCount('shared'), 1);
    expect(await refs.removeForMessage('m2'), ['shared']);
  });
}
