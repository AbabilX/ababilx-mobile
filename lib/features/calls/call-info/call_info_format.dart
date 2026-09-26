import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_translations.dart';
import '../data/models/call_log_entry.dart';

/// "24s", "3m 0s", "1h 2m" — WhatsApp's duration on the right of each call.
String callInfoDuration(int seconds) {
  if (seconds < 60) return '${seconds < 0 ? 0 : seconds}s';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h > 0) return '${h}h ${m}m';
  return '${m}m ${seconds % 60}s';
}

/// "September 24", with the year once it is not this one. Month names stay
/// English, as the chat's date dividers do.
String callInfoDayHeading(DateTime day) {
  final sameYear = day.year == DateTime.now().year;
  return DateFormat(sameYear ? 'MMMM d' : 'MMMM d, yyyy').format(day);
}

/// "6:41 PM", or "18:41" when the phone is set to a 24-hour clock.
String callInfoTime(BuildContext context, DateTime at) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(at),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

/// Incoming / Outgoing / Missed.
String callInfoDirection(CallLogEntry entry, String lang) => AppTranslations.of(
  lang,
  entry.missed
      ? 'calls_missed'
      : entry.isOutgoing
      ? 'call_info_outgoing'
      : 'call_info_incoming',
);

/// Right-hand column: how long it lasted, or why it never started. A missed
/// call already says so on the left.
String callInfoOutcome(CallLogEntry entry, String lang) {
  if (entry.connected) return callInfoDuration(entry.durationSec);
  if (entry.missed) return '';
  return AppTranslations.of(
    lang,
    entry.isOutgoing ? 'calls_no_answer' : 'calls_not_answered',
  );
}
