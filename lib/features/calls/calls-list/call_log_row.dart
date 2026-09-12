import 'package:flutter/material.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../data/models/call_log_entry.dart';
import 'call_log_format.dart';

/// One history row: who, which way the call went, when, and a redial button.
///
/// [count] is how many calls this row stands for. Signal prints it in front of
/// the state and nowhere else — "(3) Missed · 4:12" — so a stacked row still
/// reads as one event rather than becoming a second kind of row.
class CallLogRow extends StatelessWidget {
  const CallLogRow({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onCall,
    this.count = 1,
    this.lang = 'en',
  });

  final CallLogEntry entry;
  final VoidCallback onTap;
  final VoidCallback onCall;
  final int count;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    // A missed call is the one thing worth colouring — everything else is
    // routine history and should read as ordinary text.
    final accent = entry.missed ? scheme.error : scheme.onSurfaceVariant;

    final state = callSubtitle(entry, lang: lang);
    final subtitle = count > 1
        ? AppTranslations.of(
            lang,
            'calls_stacked',
          ).replaceAll('{n}', '$count').replaceAll('{what}', state)
        : state;

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
        entry.title.isEmpty
            ? AppTranslations.of(lang, 'calls_unknown')
            : entry.title,
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
              subtitle,
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
        tooltip: AppTranslations.of(
          lang,
          entry.isGroup ? 'calls_open' : 'calls_back',
        ),
      ),
    );
  }
}
