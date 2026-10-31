/// When the automatic backup runs: once a day, at a time the person picks
/// (user's call, 2026-10-30). More often than daily is not offered.
///
/// A time of day is a minute since midnight on this phone's clock. There is no
/// background job (see `LocalBackupWatcher`), so a time passed while the app
/// was closed runs on the next open.
const defaultBackupMinute = 2 * 60;

const _minutesPerDay = 24 * 60;

/// [value] when it is a real time of day, else the default.
int backupMinuteFrom(Object? value) =>
    value is int && value >= 0 && value < _minutesPerDay
    ? value
    : defaultBackupMinute;

DateTime _slotOn(DateTime day, int minuteOfDay) =>
    DateTime(day.year, day.month, day.day, minuteOfDay ~/ 60, minuteOfDay % 60);

/// Whether no backup was made since the picked time last came round.
///
/// A phone with no backup yet does not wait for the time. A last backup dated
/// ahead of the clock (the clock was moved back) cannot be measured against,
/// and must not hold backups off until that date.
bool isBackupDue({
  required int? lastMs,
  required DateTime now,
  required int minuteOfDay,
}) {
  if (lastMs == null || lastMs > now.millisecondsSinceEpoch) return true;
  final today = _slotOn(now, minuteOfDay);
  final slot = today.isAfter(now)
      ? _slotOn(DateTime(now.year, now.month, now.day - 1), minuteOfDay)
      : today;
  return lastMs < slot.millisecondsSinceEpoch;
}

/// The next time the picked minute comes round, strictly after [now].
DateTime nextBackupAt(DateTime now, int minuteOfDay) {
  final today = _slotOn(now, minuteOfDay);
  return today.isAfter(now)
      ? today
      : _slotOn(DateTime(now.year, now.month, now.day + 1), minuteOfDay);
}
