import 'package:flutter/material.dart';

/// Morning sunrise (06:00 – 10:59) — black copy.
const homeCaughtUpBgMorningAsset =
    'assets/images/home_caught_up_bg_morning.webp';

/// Afternoon countryside (11:00 – 16:59) — black copy.
const homeCaughtUpBgAfternoonAsset =
    'assets/images/home_caught_up_bg_afternoon.webp';

/// Evening sunset balcony (17:00 – 21:59) — white copy.
const homeCaughtUpBgEveningAsset =
    'assets/images/home_caught_up_bg_evening.webp';

/// Night room (22:00 – 05:59) — white copy.
const homeCaughtUpBgNightAsset = 'assets/images/home_caught_up_bg_night.webp';

const homeCaughtUpSkyMorning = Color(0xFF8EC8F0);
const homeCaughtUpSkyAfternoon = Color(0xFFADD8F7);
const homeCaughtUpSkyEvening = Color(0xFF1A2744);
const homeCaughtUpSkyNight = Color(0xFF0A1020);

/// Minutes since midnight for [now].
int _minuteOfDay(DateTime now) => now.hour * 60 + now.minute;

/// Night: 22:00 inclusive through 05:59. Clock only — not theme.
bool isHomeCaughtUpNight(DateTime now) {
  final h = now.hour;
  return h >= 22 || h < 6;
}

/// Morning: 06:00 inclusive through 10:59.
bool isHomeCaughtUpMorning(DateTime now) {
  final m = _minuteOfDay(now);
  return m >= 6 * 60 && m < 11 * 60;
}

/// Afternoon: 11:00 inclusive through 16:59 (until evening).
bool isHomeCaughtUpAfternoon(DateTime now) {
  final m = _minuteOfDay(now);
  return m >= 11 * 60 && m < 17 * 60;
}

/// Evening: 17:00 inclusive through 21:59.
bool isHomeCaughtUpEvening(DateTime now) {
  final h = now.hour;
  return h >= 17 && h < 22;
}

/// Asset + underfill + ink. Theme never picks the art — only the clock.
/// The four windows cover every hour; no leftover theme/day fallback.
({String asset, Color underfill, Color ink}) homeCaughtUpArt(DateTime now) {
  if (isHomeCaughtUpNight(now)) {
    return (
      asset: homeCaughtUpBgNightAsset,
      underfill: homeCaughtUpSkyNight,
      ink: Colors.white,
    );
  }
  if (isHomeCaughtUpMorning(now)) {
    return (
      asset: homeCaughtUpBgMorningAsset,
      underfill: homeCaughtUpSkyMorning,
      ink: Colors.black,
    );
  }
  if (isHomeCaughtUpAfternoon(now)) {
    return (
      asset: homeCaughtUpBgAfternoonAsset,
      underfill: homeCaughtUpSkyAfternoon,
      ink: Colors.black,
    );
  }
  // 17:00–21:59 (evening); night already returned above.
  return (
    asset: homeCaughtUpBgEveningAsset,
    underfill: homeCaughtUpSkyEvening,
    ink: Colors.white,
  );
}
