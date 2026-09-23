import 'package:ababilx/features/notifications/native/android_battery.dart';
import 'package:ababilx/features/notifications/vitals/battery_prompt_decision.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 9, 4, 12);

const _optimized = BatteryRestrictions(ignoringBatteryOptimizations: false);

BatteryPromptDecision _decide({
  BatteryRestrictions restrictions = _optimized,
  bool delayed = true,
  bool notificationsEnabled = true,
  bool dismissed = false,
  DateTime? lastPromptAt,
}) => decideBatteryPrompt(
  restrictions: restrictions,
  havingDelayedNotifications: delayed,
  notificationsEnabled: notificationsEnabled,
  dismissed: dismissed,
  lastPromptAt: lastPromptAt,
  now: _now,
);

void main() {
  test('measurably late pushes on an optimized phone earn the prompt', () {
    expect(_decide(), BatteryPromptDecision.promptBatterySaver);
  });

  test('never asks without evidence — the old first-launch prompt', () {
    expect(_decide(delayed: false), BatteryPromptDecision.none);
  });

  test('nothing to grant when the app is already exempt', () {
    expect(
      _decide(restrictions: BatteryRestrictions.unrestricted),
      BatteryPromptDecision.none,
    );
  });

  test('Data Saver holds the network, so the exemption would fix nothing', () {
    expect(
      _decide(
        restrictions: const BatteryRestrictions(
          ignoringBatteryOptimizations: false,
          dataSaver: DataSaverState.enabled,
        ),
      ),
      BatteryPromptDecision.none,
    );
  });

  test('being whitelisted from Data Saver is not being restricted by it', () {
    expect(
      _decide(
        restrictions: const BatteryRestrictions(
          ignoringBatteryOptimizations: false,
          dataSaver: DataSaverState.whitelisted,
        ),
      ),
      BatteryPromptDecision.promptBatterySaver,
    );
  });

  test('a muted app is not nagged about battery', () {
    expect(_decide(notificationsEnabled: false), BatteryPromptDecision.none);
  });

  test('one no is the answer', () {
    expect(_decide(dismissed: true), BatteryPromptDecision.none);
  });

  test('an unanswered prompt waits out the backoff', () {
    expect(
      _decide(lastPromptAt: _now.subtract(const Duration(days: 6))),
      BatteryPromptDecision.none,
    );
    expect(
      _decide(lastPromptAt: _now.subtract(const Duration(days: 8))),
      BatteryPromptDecision.promptBatterySaver,
    );
  });

  test('explicit restriction needs no delivered samples', () {
    expect(
      _decide(
        delayed: false,
        restrictions: const BatteryRestrictions(
          ignoringBatteryOptimizations: false,
          backgroundRestricted: true,
        ),
      ),
      BatteryPromptDecision.promptBatterySaver,
    );
  });

  test('restriction still respects refusal, permission and backoff', () {
    const restricted = BatteryRestrictions(
      ignoringBatteryOptimizations: false,
      backgroundRestricted: true,
    );
    expect(
      _decide(restrictions: restricted, delayed: false, dismissed: true),
      BatteryPromptDecision.none,
    );
    expect(
      _decide(
        restrictions: restricted,
        delayed: false,
        notificationsEnabled: false,
      ),
      BatteryPromptDecision.none,
    );
    expect(
      _decide(restrictions: restricted, delayed: false, lastPromptAt: _now),
      BatteryPromptDecision.none,
    );
  });

  test('the restricted bucket still earns the prompt, only worded harder', () {
    expect(
      _decide(
        restrictions: const BatteryRestrictions(
          ignoringBatteryOptimizations: false,
          backgroundRestricted: true,
        ),
      ),
      BatteryPromptDecision.promptBatterySaver,
    );
  });
}
