import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../messages/chat_icon.dart';
import '../models/session_state.dart';
import '../models/transfer_record.dart';

/// One row in the History tab — a single sent/received file.
class HistoryRow extends StatelessWidget {
  const HistoryRow({super.key, required this.record, required this.onTap});

  final TransferRecord record;
  final VoidCallback onTap;

  bool get _isSent => record.direction == TransferDirection.sent;

  String get _statusLabel {
    switch (record.status) {
      case FileStatus.finished:
        return _isSent ? 'Sent' : 'Received';
      case FileStatus.failed:
        return 'Failed';
      case FileStatus.canceled:
        return 'Canceled';
      case FileStatus.queue:
      case FileStatus.transferring:
        return 'Incomplete';
    }
  }

  Color _statusColor(ColorScheme scheme) {
    switch (record.status) {
      case FileStatus.finished:
        return Colors.green;
      case FileStatus.failed:
        return scheme.error;
      case FileStatus.canceled:
      case FileStatus.queue:
      case FileStatus.transferring:
        return scheme.onSurfaceVariant;
    }
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return '${size.toStringAsFixed(size >= 10 || unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            ChatIcon(
              _isSent
                  ? HugeIcons.strokeRoundedArrowDataTransferHorizontal
                  : HugeIcons.strokeRoundedDownload04,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_isSent ? 'To' : 'From'} ${record.peerAlias} · ${_formatSize(record.size)} · ${DateFormat.jm().format(record.timestamp)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _statusLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _statusColor(scheme),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
