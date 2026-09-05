import 'package:ababilx/features/attachments/data/local/attachment_ref_store.dart';
import 'package:ababilx/features/attachments/data/models/attachment_handle.dart';
import 'package:ababilx/features/attachments/storage/storage_usage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'storage_fixture.dart';

/// What Manage storage reads, against a real database.
void main() {
  final fixture = useStorageFixture();

  test('usage is grouped the way the screen draws it', () async {
    await fixture.store(
      'k1',
      fileName: 'a.jpg',
      contentType: 'image/jpeg',
      bytes: 100,
    );
    await fixture.store(
      'k2',
      fileName: 'b.jpg',
      contentType: 'image/jpeg',
      bytes: 200,
    );
    await fixture.store(
      'k3',
      fileName: 'c.mp4',
      contentType: 'video/mp4',
      bytes: 900,
    );

    final usage = await fixture.query.total();
    expect(usage.total, 1200);
    expect(usage.bytesFor(StorageBucket.photos), 300);
    expect(usage.countFor(StorageBucket.photos), 2);
    expect(usage.occupied.first, StorageBucket.videos);
  });

  test('a half-downloaded row occupies nothing the user can free', () async {
    await fixture.blobs.ensure(
      urlKey: 'k9',
      remoteUrl: 'https://cdn.example.com/k9',
      fileName: 'big.mp4',
      contentType: 'video/mp4',
      expectedBytes: 5000,
    );
    await fixture.blobs.setState(
      'k9',
      AttachmentTransferState.downloading,
      receivedBytes: 2000,
    );
    expect((await fixture.query.total()).total, 0);
  });

  test('review lists biggest first and filters by bucket', () async {
    await fixture.store(
      'k1',
      fileName: 'a.jpg',
      contentType: 'image/jpeg',
      bytes: 100,
    );
    await fixture.store(
      'k2',
      fileName: 'c.mp4',
      contentType: 'video/mp4',
      bytes: 900,
    );

    final all = await fixture.query.items();
    expect(all.map((i) => i.urlKey), ['k2', 'k1']);
    final photos = await fixture.query.items(bucket: StorageBucket.photos);
    expect(photos.single.urlKey, 'k1');
  });

  test(
    'per-chat totals count a forwarded file in every chat it is in',
    () async {
      await fixture.store(
        'k1',
        fileName: 'a.jpg',
        contentType: 'image/jpeg',
        bytes: 100,
        conversationId: 'c1',
      );
      await fixture.refs.indexAll([
        const AttachmentRefEntry(
          attachmentId: 'forwarded',
          urlKey: 'k1',
          messageId: 'm-forwarded',
          conversationId: 'c2',
        ),
      ]);

      final rows = await fixture.query.byConversation();
      expect(rows.map((r) => r.conversationId).toSet(), {'c1', 'c2'});
      // Both chats claim the same 100 bytes — the file exists once, which is
      // why these deliberately do not sum to the total.
      expect(rows.every((r) => r.bytes == 100), isTrue);
      expect((await fixture.query.total()).total, 100);
    },
  );
}
