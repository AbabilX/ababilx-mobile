import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../messages/archive/archive_provider.dart';

/// What the backup is doing, or when it last succeeded.
class ChatBackupStatusCard extends StatelessWidget {
  const ChatBackupStatusCard({super.key, required this.state});

  final ArchiveState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.busy)
            const Padding(
              padding: EdgeInsets.only(top: 3, right: 12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                state.remote == null
                    ? Icons.cloud_off_rounded
                    : Icons.cloud_done_rounded,
                color: state.remote == null
                    ? colors.onSurfaceVariant
                    : colors.primary,
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_headline(), style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  _detail(),
                  style: text.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _headline() => switch (state.phase) {
    ArchivePhase.backingUp => 'Backing up…',
    ArchivePhase.restoring => 'Restoring…',
    ArchivePhase.idle =>
      state.remote == null ? 'No phone backup yet' : 'Backup ready',
  };

  /// A count, never a percentage. The total is unknown until the export
  /// finishes, and a bar that guesses is worse than a number that is true.
  String _detail() {
    if (state.phase == ArchivePhase.backingUp) {
      return '${state.progress} messages packed';
    }
    if (state.phase == ArchivePhase.restoring) {
      return '${state.progress} messages restored';
    }
    if (!state.loaded) return 'Checking…';
    final last = state.lastBackupAt;
    if (state.remote == null) {
      return 'Your last 6 months already live free in our cloud, end-to-end '
          'encrypted. Back up this phone to also keep everything older.';
    }
    if (last == null) return 'Backed up from another device.';
    return 'Last backup ${DateFormat.yMMMd().add_jm().format(last)}';
  }
}
