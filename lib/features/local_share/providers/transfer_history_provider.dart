import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/transfer_history_store.dart';
import '../models/session_state.dart';
import '../models/transfer_record.dart';

final transferHistoryProvider =
    AsyncNotifierProvider<TransferHistoryNotifier, List<TransferRecord>>(
      TransferHistoryNotifier.new,
    );

const _terminalFileStatuses = {
  FileStatus.finished,
  FileStatus.failed,
  FileStatus.canceled,
};

class TransferHistoryNotifier extends AsyncNotifier<List<TransferRecord>> {
  @override
  Future<List<TransferRecord>> build() {
    return TransferHistoryStore.read();
  }

  /// Records every terminal file in [session]. Safe to call once per
  /// terminated session — records dedupe by id (`sessionId_fileId`) against
  /// what's already stored.
  Future<void> recordSession(ShareSessionState session) async {
    final newRecords = session.files.values
        .where((f) => _terminalFileStatuses.contains(f.status))
        .map((f) => TransferRecord.fromSession(session, f))
        .toList();
    if (newRecords.isEmpty) return;

    final current = state.valueOrNull ?? [];
    final existingIds = current.map((r) => r.id).toSet();
    final toAdd = newRecords.where((r) => !existingIds.contains(r.id)).toList();
    if (toAdd.isEmpty) return;

    final updated = await TransferHistoryStore.add(toAdd);
    state = AsyncValue.data(updated);
  }

  Future<void> clear() async {
    await TransferHistoryStore.clear();
    state = const AsyncValue.data([]);
  }
}
