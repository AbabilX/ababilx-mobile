import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backup_pin_store.dart';
import 'local_backup_failure.dart';

/// What a backup run needs before it writes anything (user's rule,
/// 2026-10-21): a backup PIN, whose key alone seals the file. No email —
/// a key-only account backs up too. Returns that key.
Future<List<int>> requireBackupKey(Ref ref, String userId) async =>
    await ref.read(backupPinStoreProvider).keyFor(userId) ??
    (throw LocalBackupFailure.needsPin);
