import 'package:ababilx/features/local-backup/data/backup_pin_store.dart';
import 'package:ababilx/features/local-backup/format/backup_crypto.dart';
import 'package:ababilx/features/local-backup/format/backup_errors.dart';
import 'package:ababilx/features/local-backup/format/backup_header.dart';
import 'package:ababilx/features/local-backup/restore/backup_key_pick.dart';
import 'package:flutter_test/flutter_test.dart';

Future<BackupHeader> headerFor(List<int> key) async {
  final salt = BackupCrypto.randomBytes(BackupCrypto.saltBytes);
  return BackupHeader(
    userId: 'u1',
    salt: salt,
    keyCheck: await BackupCrypto.keyCheck(key, salt),
    createdAtMs: 0,
  );
}

void main() {
  test('a PIN is 6 to 10 hex characters', () {
    expect(BackupPinStore.validPin('123456'), isTrue);
    expect(BackupPinStore.validPin('12a4f6'), isTrue);
    expect(BackupPinStore.validPin('12A4F6beef'), isTrue);
    expect(BackupPinStore.validPin('12345'), isFalse);
    expect(BackupPinStore.validPin('12345678901'), isFalse);
    expect(BackupPinStore.validPin('12g456'), isFalse);
  });

  test('letter case does not change the key', () async {
    final lower = await BackupPinStore.derive('u1', 'ab12cd', rounds: 1000);
    final upper = await BackupPinStore.derive('u1', 'AB12CD', rounds: 1000);
    expect(upper, lower);
  });

  test(
    'the PIN alone gives the same key again; the account salts it',
    () async {
      final a = await BackupPinStore.derive('u1', '123456', rounds: 1000);
      final again = await BackupPinStore.derive('u1', '123456', rounds: 1000);
      final otherAccount = await BackupPinStore.derive(
        'u2',
        '123456',
        rounds: 1000,
      );
      final otherPin = await BackupPinStore.derive(
        'u1',
        '654321',
        rounds: 1000,
      );
      expect(a, hasLength(32));
      expect(again, a);
      expect(otherAccount, isNot(a));
      expect(otherPin, isNot(a));
    },
  );

  test('the key whose check matches the header is picked', () async {
    final pin = await BackupPinStore.derive('u1', '123456', rounds: 1000);
    final server = BackupCrypto.randomBytes(32);
    final pinFile = await headerFor(pin);
    final oldFile = await headerFor(server);
    expect(await pickBackupKey(pinFile, [null, server, pin]), pin);
    // A media file written before the PIN still opens with the server key.
    expect(await pickBackupKey(oldFile, [pin, null, server]), server);
    expect(await pickBackupKey(pinFile, [server, null]), isNull);
  });

  test('no fitting key asks for the PIN', () async {
    final file = await headerFor(BackupCrypto.randomBytes(32));
    expect(
      () => openingKey(file, [BackupCrypto.randomBytes(32)]),
      throwsA(isA<BackupNeedsPinError>()),
    );
  });
}
