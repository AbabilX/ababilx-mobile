import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/backup_key_store.dart';
import '../data/backup_pin_store.dart';
import '../format/backup_crypto.dart';
import '../format/backup_errors.dart';
import '../format/backup_header.dart';

/// The key that opens a file, out of those this phone has: a PIN key for
/// backups made since the PIN (2026-10-21), the account's server key for
/// older files — media written once before the PIN keeps that key. Chosen by
/// the header's key check, so nothing is decrypted to find out. Null when
/// none fits.
Future<List<int>?> pickBackupKey(
  BackupHeader header,
  Iterable<List<int>?> candidates,
) async {
  for (final key in candidates) {
    if (key == null || key.length != BackupCrypto.keyBytes) continue;
    final check = await BackupCrypto.keyCheck(key, header.salt);
    if (_same(check, header.keyCheck)) return key;
  }
  return null;
}

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// Every key a file of this account may be sealed with: the PIN just typed,
/// the PIN kept on this install, then the account's server key (backups from
/// before the PIN). The server key is optional: offline, a PIN backup still
/// opens.
Future<List<List<int>?>> backupKeyCandidates(
  Ref ref,
  String userId,
  List<int>? pinKey,
) async {
  List<int>? server;
  try {
    server = await ref.read(backupKeyStoreProvider).keyFor(userId);
  } catch (_) {}
  return [
    pinKey,
    await ref.read(backupPinStoreProvider).keyFor(userId),
    server,
  ];
}

/// [pickBackupKey], or [BackupNeedsPinError]: the flow then asks for the PIN.
Future<List<int>> openingKey(
  BackupHeader header,
  Iterable<List<int>?> candidates,
) async =>
    await pickBackupKey(header, candidates) ??
    (throw const BackupNeedsPinError());
