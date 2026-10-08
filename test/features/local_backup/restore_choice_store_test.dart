import 'package:ababilx/features/local-backup/data/local_backup_settings.dart';
import 'package:ababilx/features/local-backup/data/restore_choice_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const store = RestoreChoiceStore();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('nothing chosen until the backup card is confirmed', () async {
    expect(await store.chosen('u1'), isFalse);
    expect(await store.folder('u1'), isNull);
  });

  test('a backup this install reads needs no folder', () async {
    await store.choose('u1');
    expect(await store.chosen('u1'), isTrue);
    expect(await store.folder('u1'), isNull);
    expect(await store.chosen('u2'), isFalse);
  });

  test('a granted folder is remembered until the restore is done', () async {
    await store.choose('u1', folderUri: 'content://tree/x');
    expect(await store.folder('u1'), 'content://tree/x');
    await store.clear('u1');
    expect(await store.chosen('u1'), isFalse);
  });

  test('a chosen restore arms the offer without a question', () async {
    const offers = LocalBackupSettingsStore();
    await offers.armRestoreOffer('u1', ask: !await store.chosen('u1'));
    expect(await offers.pendingRestoreOffer('u1'), RestoreOffer.ask);
    await offers.clearRestoreOffer('u1');
    await store.choose('u1');
    await offers.armRestoreOffer('u1', ask: !await store.chosen('u1'));
    expect(await offers.pendingRestoreOffer('u1'), RestoreOffer.automatic);
  });
}
