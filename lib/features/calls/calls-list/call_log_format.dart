import 'package:flutter/material.dart';

import '../../../core/localization/app_translations.dart';
import '../data/models/call_log_entry.dart';

/// Arrow that says which way the call went, as the reference app draws it:
/// missed calls get the same incoming arrow, coloured by the row rather than a
/// different glyph.
IconData callDirectionIcon(CallLogEntry entry) {
  if (entry.isGroup) return Icons.groups_rounded;
  if (entry.missed) return Icons.call_missed_rounded;
  return entry.isOutgoing
      ? Icons.call_made_rounded
      : Icons.call_received_rounded;
}

/// "Missed · 3:05 PM", "Outgoing · 4:12", "Yesterday 21:40".
///
/// Pure, and takes the language as a string for the same reason the call
/// status line does — the row that draws it is a plain StatelessWidget.
String callSubtitle(CallLogEntry entry, {String lang = 'en'}) {
  final when = callTimestamp(entry.startedAt, lang: lang);
  final what = entry.missed
      ? AppTranslations.of(lang, 'calls_missed')
      : entry.connected
      ? callDuration(entry.durationSec, lang: lang)
      : entry.isOutgoing
      ? AppTranslations.of(lang, 'calls_no_answer')
      : AppTranslations.of(lang, 'calls_not_answered');
  return '$what · $when';
}

String callDuration(int seconds, {String lang = 'en'}) {
  if (seconds <= 0) return AppTranslations.of(lang, 'calls_answered');
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  final mm = m.toString().padLeft(h > 0 ? 2 : 1, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

/// Time for today, weekday for this week, date beyond that.
String callTimestamp(DateTime at, {String lang = 'en'}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final clock =
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';
  final diff = today.difference(day).inDays;
  if (diff == 0) return clock;
  if (diff == 1) {
    return AppTranslations.of(
      lang,
      'calls_yesterday',
    ).replaceAll('{time}', clock);
  }
  if (diff < 7) {
    return '${AppTranslations.of(lang, _weekdayKeys[at.weekday - 1])} $clock';
  }
  return '${at.day}/${at.month}/${at.year}';
}

/// Date-only heading used to break the call log into scannable sections.
String callDateHeading(DateTime at, {String lang = 'en'}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return AppTranslations.of(lang, 'calls_today');
  if (diff == 1) return AppTranslations.of(lang, 'calls_yesterday_heading');
  if (diff > 1 && diff < 7) {
    return AppTranslations.of(lang, _weekdayKeys[at.weekday - 1]);
  }
  return '${at.day}/${at.month}/${at.year}';
}

const _weekdayKeys = [
  'calls_mon',
  'calls_tue',
  'calls_wed',
  'calls_thu',
  'calls_fri',
  'calls_sat',
  'calls_sun',
];
