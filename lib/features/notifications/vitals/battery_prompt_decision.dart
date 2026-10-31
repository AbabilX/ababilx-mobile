import '../native/android_battery.dart';

/// What the vitals check concluded.
enum BatteryPromptDecision {
  /// Say nothing. The overwhelmingly common answer.
  none,

  /// Notifications are measurably late and the exemption could fix it.
  promptBatterySaver,
}

/// Whether to ask this user to exempt the app from battery optimization.
///
/// The app used to ask on the first frame after login, before a single push had
/// been delivered — a system dialog with a scary warning in it, shown to
/// everyone, justified by nothing. The reference app's rule is the opposite and
/// is the one implemented here: the prompt has to be *earned* by evidence that
/// this phone is actually holding notifications, and it is only worth showing
/// when the exemption would change the outcome.
///
/// Each gate, in order:
///
///  - **Notifications off.** Nothing to fix, and asking about battery while the
///    user has muted the app reads as nagging.
///  - **Already dismissed.** One "no" is the answer, not a round in a
///    negotiation. The settings tile stays for anyone who changes their mind.
///  - **Asked recently.** [backoff] between prompts, so an unanswered sheet
///    (swiped away) does not come back tomorrow.
///  - **No evidence.** See `isHavingDelayedNotifications`.
///  - **Already exempt.** There is nothing left to grant.
///  - **Data Saver on for this app.** The OS is withholding background network
///    whatever the battery bucket says, so the exemption fixes nothing and the
///    dialog would be a lie. Whitelisted does not count — traffic flows there.
///
/// An explicit `backgroundRestricted` state also counts as evidence: a phone
/// blocking every push cannot accumulate latency samples.
BatteryPromptDecision decideBatteryPrompt({
  required BatteryRestrictions restrictions,
  required bool havingDelayedNotifications,
  required bool notificationsEnabled,
  required bool dismissed,
  required DateTime? lastPromptAt,
  required DateTime now,
  Duration backoff = const Duration(days: 7),
}) {
  if (!notificationsEnabled) return BatteryPromptDecision.none;
  if (dismissed) return BatteryPromptDecision.none;
  if (lastPromptAt != null && now.difference(lastPromptAt) < backoff) {
    return BatteryPromptDecision.none;
  }
  // An explicit OS restriction is evidence even when no push can wake Dart
  // to record a latency sample. Ordinary optimization still needs samples.
  if (!havingDelayedNotifications && !restrictions.backgroundRestricted) {
    return BatteryPromptDecision.none;
  }
  if (restrictions.ignoringBatteryOptimizations) {
    return BatteryPromptDecision.none;
  }
  if (restrictions.dataSaver == DataSaverState.enabled) {
    return BatteryPromptDecision.none;
  }
  return BatteryPromptDecision.promptBatterySaver;
}
