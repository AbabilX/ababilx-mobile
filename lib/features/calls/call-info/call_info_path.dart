import '../data/models/call_log_entry.dart';

/// `/call-info/<conversation>?day=2026-9-24` — one contact, one calendar day,
/// the same day the call log's stacked row stands for.
String callInfoPath(CallLogEntry entry) {
  final at = entry.startedAt;
  return '/call-info/${Uri.encodeComponent(entry.conversationId)}'
      '?day=${at.year}-${at.month}-${at.day}';
}

/// The day a [callInfoPath] names, or today when it is missing or malformed.
DateTime parseCallInfoDay(String? raw) {
  final parts = (raw ?? '').split('-').map(int.tryParse).toList();
  if (parts.length == 3 && !parts.contains(null)) {
    return DateTime(parts[0]!, parts[1]!, parts[2]!);
  }
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// That contact's calls on [day], oldest first — WhatsApp's Call info reads
/// down the day in the order it happened. [calls] is the log, newest first.
List<CallLogEntry> callsOnDay(
  List<CallLogEntry> calls, {
  required String conversationId,
  required DateTime day,
}) => calls.reversed
    .where(
      (c) =>
          c.conversationId == conversationId &&
          c.startedAt.year == day.year &&
          c.startedAt.month == day.month &&
          c.startedAt.day == day.day,
    )
    .toList();
