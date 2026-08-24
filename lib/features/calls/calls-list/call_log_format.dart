import 'package:flutter/material.dart';

import '../data/models/call_log_entry.dart';

/// Arrow that says which way the call went, Signal-style: missed calls get the
/// same incoming arrow, coloured by the row rather than a different glyph.
IconData callDirectionIcon(CallLogEntry entry) {
  if (entry.isGroup) return Icons.groups_rounded;
  if (entry.missed) return Icons.call_missed_rounded;
  return entry.isOutgoing
      ? Icons.call_made_rounded
      : Icons.call_received_rounded;
}

/// "Missed · 3:05 PM", "Outgoing · 4:12", "Yesterday 21:40".
String callSubtitle(CallLogEntry entry) {
  final when = callTimestamp(entry.startedAt);
  final what = entry.missed
      ? 'Missed'
      : entry.connected
      ? callDuration(entry.durationSec)
      : entry.isOutgoing
      ? 'No answer'
      : 'Not answered';
  return '$what · $when';
}

String callDuration(int seconds) {
  if (seconds <= 0) return 'Answered';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  final mm = m.toString().padLeft(h > 0 ? 2 : 1, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

/// Time for today, weekday for this week, date beyond that.
String callTimestamp(DateTime at) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final clock =
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';
  final diff = today.difference(day).inDays;
  if (diff == 0) return clock;
  if (diff == 1) return 'Yesterday $clock';
  if (diff < 7) return '${_weekdays[at.weekday - 1]} $clock';
  return '${at.day}/${at.month}/${at.year}';
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
