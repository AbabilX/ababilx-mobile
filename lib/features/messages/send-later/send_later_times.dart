import 'package:intl/intl.dart';

/// Send later's time rules. The server's are the same
/// (`services/chat/scheduled.go`): at least a minute ahead, at most 120 days
/// — the chat retention window.
const sendLaterMinAhead = Duration(minutes: 1);
const sendLaterMaxAhead = Duration(days: 120);

bool sendLaterTimeAllowed(DateTime at, DateTime now) {
  final ahead = at.difference(now);
  return ahead >= sendLaterMinAhead && ahead <= sendLaterMaxAhead;
}

class SendLaterPreset {
  const SendLaterPreset(this.label, this.at);

  final String label;
  final DateTime at;
}

/// The sheet's quick rows, picked by the time of day: "Today 9 PM" is gone
/// once it is 8 PM, since it would be under an hour away or already past.
///
/// Built from calendar fields, not by adding hours to midnight: a day with a
/// clock change is 23 or 25 hours long.
List<SendLaterPreset> sendLaterPresets(DateTime now) {
  DateTime day(int offset, int hour) =>
      DateTime(now.year, now.month, now.day + offset, hour);
  final inAnHour = now.add(const Duration(hours: 1));
  return [
    SendLaterPreset(
      'In 1 hour',
      DateTime(
        inAnHour.year,
        inAnHour.month,
        inAnHour.day,
        inAnHour.hour,
        inAnHour.minute,
      ),
    ),
    if (now.hour < 20) SendLaterPreset('Today 9 PM', day(0, 21)),
    SendLaterPreset('Tomorrow 9 AM', day(1, 9)),
    SendLaterPreset('Tomorrow 9 PM', day(1, 21)),
  ];
}

/// "Today 9:00 PM", "Tomorrow 9:00 AM", "Sat 9:00 PM", "12 Nov, 9:00 PM".
String formatSendAt(DateTime at, {DateTime? now}) {
  final today = now ?? DateTime.now();
  // Calendar days counted in UTC: a local midnight-to-midnight across a
  // clock change is 23 h, which `inDays` reads as 0.
  final days = DateTime.utc(
    at.year,
    at.month,
    at.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  final time = DateFormat('h:mm a').format(at);
  if (days == 0) return 'Today $time';
  if (days == 1) return 'Tomorrow $time';
  if (days > 1 && days < 7) return '${DateFormat('EEE').format(at)} $time';
  if (at.year == today.year) return DateFormat('d MMM, h:mm a').format(at);
  return DateFormat('d MMM yyyy, h:mm a').format(at);
}
