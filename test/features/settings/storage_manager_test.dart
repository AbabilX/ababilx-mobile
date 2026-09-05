import 'package:ababilx/features/attachments/data/models/attachment_handle.dart';
import 'package:flutter_test/flutter_test.dart';

import 'storage_fixture.dart';

/// What Manage storage deletes, against a real database and real files.
void main() {
  final fixture = useStorageFixture();

  test('deleting frees the file but keeps the row downloadable', () async {
    final file = await fixture.store(
      'k1',
      fileName: 'a.jpg',
      contentType: 'image/jpeg',
      bytes: 100,
    );

    expect(await fixture.manager.release(['k1']), 100);
    expect(await file.exists(), isFalse);
    // The message keeps its attachment: absent, not gone, so the bubble shows
    // a download badge instead of a broken tile.
    final row = await fixture.blobs.read('k1');
    expect(row, isNotNull);
    expect(row!.transferState, AttachmentTransferState.absent.index);
    expect((await fixture.query.total()).total, 0);
  });

  test('a file two rows share survives one of them being cleared', () async {
    final file = await fixture.store(
      'k1',
      fileName: 'a.jpg',
      contentType: 'image/jpeg',
      bytes: 100,
      sharedPath: 'shared.jpg',
    );
    await fixture.store(
      'k2',
      fileName: 'a.jpg',
      contentType: 'image/jpeg',
      bytes: 100,
      sharedPath: 'shared.jpg',
    );

    // Nothing was reclaimed: the other row is still reading these bytes.
    expect(await fixture.manager.release(['k1']), 0);
    expect(await file.exists(), isTrue);
    expect(await fixture.manager.release(['k2']), 100);
    expect(await file.exists(), isFalse);
  });

  test('clearing one chat leaves the others alone', () async {
    await fixture.store(
      'k1',
      fileName: 'a.jpg',
      contentType: 'image/jpeg',
      bytes: 100,
      conversationId: 'c1',
    );
    await fixture.store(
      'k2',
      fileName: 'b.jpg',
      contentType: 'image/jpeg',
      bytes: 200,
      conversationId: 'c2',
    );

    expect(await fixture.manager.releaseConversation('c1'), 100);
    expect((await fixture.query.total()).total, 200);
    expect(await fixture.manager.releaseAll(), 200);
    expect((await fixture.query.total()).total, 0);
  });

  test('deleting older media leaves undated rows alone', () async {
    await fixture.store(
      'old',
      fileName: 'a.jpg',
      contentType: 'image/jpeg',
      bytes: 100,
    );
    await fixture.store(
      'new',
      fileName: 'b.jpg',
      contentType: 'image/jpeg',
      bytes: 200,
    );
    await fixture.store(
      'undated',
      fileName: 'c.jpg',
      contentType: 'image/jpeg',
      bytes: 50,
    );
    final ninetyDaysAgo = DateTime.now().subtract(const Duration(days: 90));
    await fixture.db.customStatement(
      'UPDATE attachment_blobs SET downloaded_at_ms = ? WHERE url_key = ?',
      [ninetyDaysAgo.millisecondsSinceEpoch, 'old'],
    );
    // A row written before the column existed: 0 must not read as 1970.
    await fixture.db.customStatement(
      'UPDATE attachment_blobs SET downloaded_at_ms = NULL WHERE url_key = ?',
      ['undated'],
    );

    final freed = await fixture.manager.releaseOlderThan(
      DateTime.now().subtract(const Duration(days: 30)),
    );
    expect(freed, 100);
    expect((await fixture.query.total()).total, 250);
  });
}
