import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/chat_icon.dart';
import '../data/models/call_log_entry.dart';
import 'call_info_format.dart';

/// One call on the Call info page: arrow, "Incoming" over the time, and the
/// duration on the right.
class CallInfoRow extends StatelessWidget {
  const CallInfoRow({super.key, required this.entry, required this.lang});

  final CallLogEntry entry;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final accent = entry.missed ? scheme.error : scheme.primary;
    final time = callInfoTime(context, entry.startedAt);
    final kind = entry.isVideo
        ? AppTranslations.of(lang, 'call_info_video')
        : entry.isScreenShare
        ? AppTranslations.of(lang, 'call_info_screen')
        : null;

    return ListTile(
      minTileHeight: 68,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: SizedBox(
        width: 40,
        child: Center(
          child: ChatIcon(
            entry.missed
                ? HugeIcons.strokeRoundedCallMissed01
                : entry.isOutgoing
                ? HugeIcons.strokeRoundedCallOutgoing01
                : HugeIcons.strokeRoundedCallIncoming01,
            size: 24,
            color: accent,
            strokeWidth: 1.6,
          ),
        ),
      ),
      title: Text(
        callInfoDirection(entry, lang),
        style: text.titleMedium?.copyWith(
          color: entry.missed ? scheme.error : scheme.onSurface,
        ),
      ),
      subtitle: Text(
        kind == null ? time : '$time · $kind',
        style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      trailing: Text(
        callInfoOutcome(entry, lang),
        style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}
