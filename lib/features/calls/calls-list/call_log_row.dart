import 'package:flutter/material.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../data/models/call_log_entry.dart';
import 'call_log_format.dart';

/// One history row: who, which way the call went, when, and a redial button.
class CallLogRow extends StatelessWidget {
  const CallLogRow({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onCall,
  });

  final CallLogEntry entry;
  final VoidCallback onTap;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    // A missed call is the one thing worth colouring — everything else is
    // routine history and should read as ordinary text.
    final accent = entry.missed ? scheme.error : scheme.onSurfaceVariant;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: entry.isGroup
          ? CircleAvatar(
              backgroundColor: scheme.surfaceContainerHighest,
              child: Icon(Icons.groups_rounded, color: scheme.onSurfaceVariant),
            )
          : AppAvatar(size: 44, url: entry.avatarUrl, name: entry.title),
      title: Text(
        entry.title.isEmpty ? 'Unknown' : entry.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: text.titleMedium?.copyWith(
          fontWeight: entry.missed ? FontWeight.w700 : FontWeight.w600,
          color: entry.missed ? scheme.error : scheme.onSurface,
        ),
      ),
      subtitle: Row(
        children: [
          Icon(callDirectionIcon(entry), size: 15, color: accent),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              callSubtitle(entry),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: accent),
            ),
          ),
        ],
      ),
      trailing: IconButton(
        onPressed: onCall,
        icon: Icon(
          entry.isGroup
              ? Icons.video_call_rounded
              : entry.isScreenShare
              ? Icons.screen_share_outlined
              : entry.isVideo
              ? Icons.videocam_rounded
              : Icons.call_rounded,
          color: scheme.primary,
        ),
        tooltip: entry.isGroup ? 'Open call' : 'Call back',
      ),
    );
  }
}
