import 'package:permission_handler/permission_handler.dart';

import '../native/android_battery.dart';
import 'battery_prompt_decision.dart';
import 'push_latency_store.dart';
import 'slow_notification_heuristics.dart';
import 'vitals_prefs.dart';

/// The decision, plus the OS state it was made from (the prompt words itself
/// differently for a phone the user has put in the restricted bucket).
class NotificationVitals {
  const NotificationVitals({
    required this.decision,
    required this.restrictions,
  });

  static const none = NotificationVitals(
    decision: BatteryPromptDecision.none,
    restrictions: BatteryRestrictions.unrestricted,
  );

  final BatteryPromptDecision decision;
  final BatteryRestrictions restrictions;
}

/// Runs the vitals check — Signal's `VitalsViewModel`, minus the parts that
/// have no counterpart here (crash prompts, websocket connectivity warnings).
///
/// Called on every resume, so it is throttled the way Signal throttles it: at
/// most one real check a minute, whatever the lifecycle does.
class NotificationVitalsCheck {
  const NotificationVitalsCheck._();

  static const _throttle = Duration(minutes: 1);

  static DateTime? _lastRun;

  /// Resets the throttle so the next [run] actually checks. For tests and for
  /// the moment right after the user answers the prompt.
  static void reset() => _lastRun = null;

  static Future<NotificationVitals> run() async {
    if (!AndroidBattery.supported) return NotificationVitals.none;
    final now = DateTime.now();
    final last = _lastRun;
    if (last != null && now.difference(last) < _throttle) {
      return NotificationVitals.none;
    }
    _lastRun = now;

    // Everything the decision needs, gathered before deciding anything — the
    // rules live in `decideBatteryPrompt` alone, so there is one place to read
    // them and one place to change them.
    final restrictions = await AndroidBattery.status();
    final samples = await PushLatencyStore.read(at: now);
    final decision = decideBatteryPrompt(
      restrictions: restrictions,
      havingDelayedNotifications: isHavingDelayedNotifications(samples, now),
      notificationsEnabled: await _notificationsEnabled(),
      dismissed: await NotificationVitalsPrefs.dismissed(),
      lastPromptAt: await NotificationVitalsPrefs.lastPromptAt(),
      now: now,
    );
    return NotificationVitals(decision: decision, restrictions: restrictions);
  }

  static Future<bool> _notificationsEnabled() async {
    try {
      return await Permission.notification.isGranted;
    } catch (_) {
      // Unknown counts as enabled: a phone we cannot ask about should still be
      // able to earn the prompt, since the evidence gate is the real filter.
      return true;
    }
  }
}
