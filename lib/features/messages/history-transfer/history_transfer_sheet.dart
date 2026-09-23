import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'history_transfer_approval.dart';
import 'history_transfer_exporter.dart';
import 'history_transfer_provider.dart';

/// The one screen the phone shows for a transfer: what is being approved
/// before it starts, and how far it has got after.
class HistoryTransferSheet {
  HistoryTransferSheet._();

  static Future<bool?> confirm(
    BuildContext context,
    HistoryTransferRequestView view,
  ) {
    final colors = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send your history to this device?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${view.label} is asking for the messages and files on this '
              'phone, including ones the server no longer keeps.',
            ),
            const SizedBox(height: 14),
            Text(
              'Only continue if this code matches the one on that screen.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                view.code,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 6,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Your phone keeps everything it has. Sending can take a while '
              'on a large history and continues in the background.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Reject'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Send history'),
          ),
        ],
      ),
    );
  }
}

/// A quiet line for a transfer in flight. Shows nothing when none is running,
/// so it can sit on a settings screen without becoming furniture.
class HistoryTransferStatusTile extends ConsumerWidget {
  const HistoryTransferStatusTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(historyTransferProvider);
    if (state.transferId.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      leading: state.busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              state.error.isEmpty ? Icons.check_circle : Icons.error_outline,
              color: state.error.isEmpty ? colors.primary : colors.error,
            ),
      title: Text(_title(state)),
      subtitle: Text(_subtitle(state), style: TextStyle(fontSize: 12)),
      trailing: state.busy
          ? TextButton(
              onPressed: () =>
                  ref.read(historyTransferProvider.notifier).cancel(),
              child: const Text('Cancel'),
            )
          : TextButton(
              onPressed: () {
                final notifier = ref.read(historyTransferProvider.notifier);
                state.error.isNotEmpty ? notifier.retry() : notifier.dismiss();
              },
              child: Text(state.error.isNotEmpty ? 'Retry' : 'OK'),
            ),
    );
  }

  String _title(HistoryTransferState state) {
    if (state.error.isNotEmpty) return 'History transfer stopped';
    if (state.finished) return 'History sent';
    return switch (state.phase) {
      HistoryTransferPhase.snapshot => 'Preparing your history',
      HistoryTransferPhase.upload => 'Sending your history',
      HistoryTransferPhase.manifest => 'Finishing up',
      null => 'History transfer',
    };
  }

  /// Missing files are named even on success. A transfer that moved every
  /// message and could not find four photos is not "everything transferred",
  /// and the phone is the only side that knows which files were never there.
  String _subtitle(HistoryTransferState state) {
    final missing = state.missingFiles > 0
        ? ' · ${state.missingFiles} file(s) not on this phone'
        : '';
    if (state.error.isNotEmpty) {
      return 'Scan again from that device to resume.$missing';
    }
    if (state.finished) {
      return state.missingFiles > 0
          ? 'Everything this phone still has was sent.$missing'
          : 'Messages and files transferred.';
    }
    final part = state.batches > 1
        ? 'Part ${state.batch + 1} of ${state.batches} · '
        : '';
    if (state.waiting) {
      return '${part}Waiting for the other device to save it. Keep AbabilX open.$missing';
    }
    if (state.phase == HistoryTransferPhase.upload && state.total > 0) {
      return '$part${state.done} of ${state.total} pieces · Keep AbabilX open$missing';
    }
    return 'Keep AbabilX open while sending.$missing';
  }
}
