import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/router/shell_bottom_bar/shell_pill_metrics.dart';
import '../models/transfer_record.dart';
import '../providers/transfer_history_provider.dart';
import '../widgets/history_row.dart';

/// Sent + received transfer log — persists across app restarts.
class HistoryTab extends ConsumerWidget {
  const HistoryTab({super.key});

  Future<void> _openRecord(BuildContext context, TransferRecord record) async {
    if (record.direction != TransferDirection.received || record.path == null) {
      return;
    }

    final result = await OpenFilex.open(record.path!);
    if (result.type != ResultType.done && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open file: ${result.message}')),
      );
    }
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text(
          'This only clears the log — files on disk are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(transferHistoryProvider.notifier).clear();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final historyAsync = ref.watch(transferHistoryProvider);

    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Could not load history',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      ),
      data: (records) {
        if (records.isEmpty) {
          return Center(
            child: Text(
              'No transfers yet',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          );
        }

        final groups = <String, List<TransferRecord>>{};
        for (final record in records) {
          final label = _dayLabel(record.timestamp);
          groups.putIfAbsent(label, () => []).add(record);
        }

        return ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            ShellPillMetrics.contentBottomInset,
          ),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'History',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: scheme.onSurface,
                  ),
                ),
                TextButton(
                  onPressed: () => _confirmClear(context, ref),
                  child: const Text('Clear'),
                ),
              ],
            ),
            for (final entry in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Text(
                  entry.key,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final record in entry.value)
                HistoryRow(
                  record: record,
                  onTap: () => _openRecord(context, record),
                ),
            ],
          ],
        );
      },
    );
  }

  String _dayLabel(DateTime timestamp) {
    final now = DateTime.now();
    final date = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(date).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat.yMMMd().format(timestamp);
  }
}
