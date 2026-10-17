/// How far back this phone sends history to a newly linked web or desktop
/// device: three months (user's call, 2026-10-18 — WhatsApp's window). Older
/// messages stay on the phone.
///
/// The server states the number (`history_days` on transfer info,
/// `history_window_days` on capabilities, migration 0174) so every phone build
/// reads the same one; it only relays ciphertext and cannot check it. This is
/// the fallback for a server that predates it.
const int defaultHistoryWindowDays = 90;

/// The server's figure, or the default when it is missing or not positive.
int historyWindowDays(Object? value) {
  final days = value is num ? value.toInt() : 0;
  return days > 0 ? days : defaultHistoryWindowDays;
}

/// The export cursor a transfer starts from. `exportPage(afterMs:)` returns
/// rows strictly after it, so a message sent exactly at the cutoff is in.
int historyWindowAfterMs(int days, DateTime now) =>
    now.subtract(Duration(days: days)).millisecondsSinceEpoch - 1;

/// "3 months" for the confirmation copy; days when it is not whole months.
String historyWindowLabel(int days) {
  if (days % 30 != 0) return days == 1 ? '1 day' : '$days days';
  final months = days ~/ 30;
  return months == 1 ? '1 month' : '$months months';
}
