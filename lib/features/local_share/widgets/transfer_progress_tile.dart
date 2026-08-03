import 'package:flutter/material.dart';

import '../models/session_state.dart';

/// Single-file progress row shown inside an active/finished transfer session.
class TransferProgressTile extends StatelessWidget {
  const TransferProgressTile({super.key, required this.progress});

  final FileTransferProgress progress;

  String get _statusLabel {
    switch (progress.status) {
      case FileStatus.queue:
        return 'Waiting…';
      case FileStatus.transferring:
        return '${(progress.progress * 100).toStringAsFixed(0)}%';
      case FileStatus.finished:
        return 'Done';
      case FileStatus.failed:
        return progress.errorMessage ?? 'Failed';
      case FileStatus.canceled:
        return 'Canceled';
    }
  }

  Color _statusColor(ColorScheme scheme) {
    switch (progress.status) {
      case FileStatus.finished:
        return Colors.green;
      case FileStatus.failed:
        return scheme.error;
      case FileStatus.canceled:
        return scheme.onSurfaceVariant;
      case FileStatus.queue:
      case FileStatus.transferring:
        return scheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _statusColor(scheme);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  progress.file.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(_statusLabel, style: TextStyle(fontSize: 12, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.status == FileStatus.finished
                  ? 1.0
                  : progress.progress,
              minHeight: 4,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
