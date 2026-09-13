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

    final title = entry.title.isEmpty
        ? AppTranslations.of(lang, 'calls_unknown')
        : entry.title;
    final actionLabel = AppTranslations.of(
      lang,
      entry.isGroup ? 'calls_open' : 'calls_back',
    );

    return Semantics(
      button: true,
      label: '$title, $subtitle',
      child: ListTile(
        onTap: onTap,
        minTileHeight: 72,
        contentPadding: const EdgeInsets.fromLTRB(20, 6, 12, 6),
        leading: entry.isGroup
            ? CircleAvatar(
                radius: 24,
                backgroundColor: scheme.secondaryContainer,
                child: Icon(
                  Icons.groups_rounded,
                  color: scheme.onSecondaryContainer,
                ),
              )
            : AppAvatar(size: 48, url: entry.avatarUrl, name: title),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.titleMedium?.copyWith(
            fontWeight: entry.missed ? FontWeight.w700 : FontWeight.w600,
            color: entry.missed ? scheme.error : scheme.onSurface,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Row(
            children: [
              Icon(callDirectionIcon(entry), size: 15, color: accent),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(color: accent),
                ),
              ),
            ],
          ),
        ),
        trailing: Semantics(
          button: true,
          label: actionLabel,
          excludeSemantics: true,
          child: IconButton.filledTonal(
            onPressed: onCall,
            icon: Icon(
              entry.isGroup
                  ? Icons.arrow_forward_rounded
                  : entry.isScreenShare
                  ? Icons.screen_share_outlined
                  : entry.isVideo
                  ? Icons.videocam_rounded
                  : Icons.call_rounded,
            ),
            tooltip: actionLabel,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            style: IconButton.styleFrom(
              foregroundColor: scheme.primary,
              backgroundColor: scheme.primaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}
