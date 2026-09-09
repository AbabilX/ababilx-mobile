import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../attachments/providers/attachment_providers.dart';
import '../data/local/chat_message_store.dart';
import '../data/local/chat_sidebar_cache.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'history_transfer_api.dart';
import 'history_transfer_exporter.dart';

final historyTransferApiProvider = Provider<HistoryTransferApi>(
  (ref) => HistoryTransferApi(ref.watch(apiClientProvider)),
);

/// What the phone is doing for a transfer it approved.
///
/// Sending is deliberately NOT modal: the user approved a transfer, they did
/// not agree to stare at a progress bar for an hour of video. The state lives
/// here so a sheet can show it and the chat list can carry a quiet line.
class HistoryTransferState {
  const HistoryTransferState({
    this.transferId = '',
    this.phase,
    this.done = 0,
    this.total = 0,
    this.missingFiles = 0,
    this.error = '',
    this.finished = false,
  });

  final String transferId;
  final HistoryTransferPhase? phase;
  final int done;
  final int total;

  /// Files the phone no longer holds. Reported apart from progress, because a
  /// transfer that moved every message and four missing photos must never
  /// read as "everything transferred".
  final int missingFiles;
  final String error;
  final bool finished;

  bool get busy => transferId.isNotEmpty && !finished && error.isEmpty;

  HistoryTransferState copyWith({
    String? transferId,
    HistoryTransferPhase? phase,
    int? done,
    int? total,
    int? missingFiles,
    String? error,
    bool? finished,
  }) => HistoryTransferState(
    transferId: transferId ?? this.transferId,
    phase: phase ?? this.phase,
    done: done ?? this.done,
    total: total ?? this.total,
    missingFiles: missingFiles ?? this.missingFiles,
    error: error ?? this.error,
    finished: finished ?? this.finished,
  );
}

class HistoryTransferNotifier extends Notifier<HistoryTransferState> {
  @override
  HistoryTransferState build() => const HistoryTransferState();

  bool _cancelled = false;

  /// Runs the export for a transfer the user has already approved.
  ///
  /// The key is passed in rather than read back: it was minted for the
  /// approval and sealed to the scanned device there, and nothing durable
  /// holds it except this transfer's own snapshot.
  Future<void> send({
    required String transferId,
    required List<int> transferKey,
    required String deviceId,
  }) async {
    _cancelled = false;
    state = HistoryTransferState(
      transferId: transferId,
      phase: HistoryTransferPhase.snapshot,
    );
    try {
      final outcome =
          await HistoryTransferExporter(
            api: ref.read(historyTransferApiProvider),
            store: ref.read(chatMessageStoreProvider),
            blobs: ref.read(attachmentBlobStoreProvider),
            isCancelled: () => _cancelled,
            onPhase: (phase, done, total) =>
                state = state.copyWith(phase: phase, done: done, total: total),
          ).run(
            transferId: transferId,
            transferKey: transferKey,
            deviceId: deviceId,
            conversations: await _conversations(),
          );
      state = state.copyWith(
        finished: outcome.completed,
        missingFiles: outcome.missingFiles,
      );
    } catch (error) {
      // The transfer is left open on purpose: its window is 24 hours, so a
      // failed run can be resumed from the snapshot rather than restarted.
      state = state.copyWith(error: error.toString());
    }
  }

  /// Stops the upload and ends the transfer for both devices. Cancelling is
  /// the only thing besides expiry that closes it — the destination cannot
  /// take it over.
  Future<void> cancel() async {
    _cancelled = true;
    final id = state.transferId;
    if (id.isEmpty) return;
    try {
      await ref.read(historyTransferApiProvider).cancel(id);
    } catch (_) {
      // The window expires on its own; a failed cancel is not worth a dialog.
    }
    state = const HistoryTransferState();
  }

  /// The sidebar cache is the only local enumeration of conversations there
  /// is. Best effort: without it every message still transfers, there is just
  /// nothing to name the threads until the destination's first sidebar fetch.
  Future<List<ChatConversation>> _conversations() async {
    try {
      final userId = ref.read(chatProvider).currentUserId;
      if (userId.isEmpty) return const [];
      final sidebar = await ChatSidebarCache(
        ref.read(chatLocalDbProvider),
      ).read(userId);
      if (sidebar == null) return const [];
      return [...sidebar.channels, ...sidebar.dms];
    } catch (_) {
      return const [];
    }
  }
}

final historyTransferProvider =
    NotifierProvider<HistoryTransferNotifier, HistoryTransferState>(
      HistoryTransferNotifier.new,
    );
