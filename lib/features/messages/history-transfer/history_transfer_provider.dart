import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../attachments/providers/attachment_providers.dart';
import '../data/local/chat_message_store.dart';
import '../data/models/chat_models.dart';
import 'history_transfer_api.dart';
import 'history_transfer_exporter.dart';
import 'history_transfer_local_conversations.dart';
import 'history_transfer_state.dart';

export 'history_transfer_state.dart';
import 'v2/v2_api.dart';
import 'v2/v2_exporter.dart';
import 'v2/v2_store.dart';

final historyTransferApiProvider = Provider<HistoryTransferApi>(
  (ref) => HistoryTransferApi(ref.watch(apiClientProvider)),
);

final historyTransferV2ApiProvider = Provider<HistoryTransferV2Api>(
  (ref) => HistoryTransferV2Api(ref.watch(apiClientProvider)),
);

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

  Future<List<ChatConversation>> _conversations() =>
      localTransferConversations(ref);

  /// Protocol v2 (`v2/`): batches, messages before media. `transferKey` is
  /// null on a resume, and read back from secure storage.
  Future<void> sendV2({required String transferId, List<int>? transferKey}) async {
    _cancelled = false;
    state = HistoryTransferState(transferId: transferId, phase: HistoryTransferPhase.snapshot);
    try {
      final outcome = await HistoryTransferV2Exporter(
        api: ref.read(historyTransferV2ApiProvider),
        messages: ref.read(chatMessageStoreProvider),
        blobs: ref.read(attachmentBlobStoreProvider),
        conversations: await _conversations(),
        isCancelled: () => _cancelled,
        onProgress: (phase, batch, batches, done, total) => state = state.copyWith(
          phase: phase == V2Phase.planning ? HistoryTransferPhase.snapshot : HistoryTransferPhase.upload,
          batch: batch,
          batches: batches,
          done: done,
          total: total,
          waiting: phase == V2Phase.waiting,
        ),
      ).run(transferId: transferId, transferKey: transferKey);
      state = state.copyWith(
        finished: outcome.completed,
        waiting: false,
        missingFiles: outcome.filesMissing + outcome.filesOmitted,
        error: outcome.completed || _cancelled ? '' : 'The other device stopped the transfer.',
      );
    } catch (error) {
      // Left open: the window is 24 hours and the plan is on disk, so the
      // next launch (or Retry) resumes rather than restarts.
      state = state.copyWith(error: historyTransferFailure(error), waiting: false);
    }
  }

  /// After a failure: the plan and key are still here, so this resumes.
  Future<void> retry() async {
    state = const HistoryTransferState();
    await resumeIfPending();
  }

  /// Clears a finished line off the chat list.
  void dismiss() => state = const HistoryTransferState();

  /// Picks up a v2 transfer this phone was sending when it was closed.
  Future<void> resumeIfPending() async {
    if (state.busy) return;
    try {
      final active = await ref.read(historyTransferApiProvider).active();
      if (active == null || active['role'] != 'source' || active['status'] != 'approved') return;
      final id = active['id'] as String? ?? '';
      if (id.isEmpty || await (await V2Store.open(id)).readKey(id) == null) return;
      await sendV2(transferId: id);
    } catch (_) {
      // Nothing to resume, or no network yet; the next launch asks again.
    }
  }
}

final historyTransferProvider =
    NotifierProvider<HistoryTransferNotifier, HistoryTransferState>(
      HistoryTransferNotifier.new,
    );
