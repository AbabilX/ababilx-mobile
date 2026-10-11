import 'package:ababilx/features/messages/send-later/send_later_times.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sendLaterPresets', () {
    test('morning offers today 9 PM and both of tomorrow', () {
      final now = DateTime(2026, 10, 11, 10, 15, 42);
      final presets = sendLaterPresets(now);
      expect(presets.map((p) => p.label), [
        'In 1 hour',
        'Today 9 PM',
        'Tomorrow 9 AM',
        'Tomorrow 9 PM',
      ]);
      expect(presets[0].at, DateTime(2026, 10, 11, 11, 15));
      expect(presets[1].at, DateTime(2026, 10, 11, 21));
      expect(presets[2].at, DateTime(2026, 10, 12, 9));
      expect(presets[3].at, DateTime(2026, 10, 12, 21));
    });

    test('from 8 PM today 9 PM is gone', () {
      for (final hour in [20, 21, 23]) {
        final labels = sendLaterPresets(
          DateTime(2026, 10, 11, hour),
        ).map((p) => p.label);
        expect(labels, isNot(contains('Today 9 PM')), reason: 'at $hour:00');
        expect(labels.length, 3);
      }
      expect(
        sendLaterPresets(DateTime(2026, 10, 11, 19, 59)).map((p) => p.label),
        contains('Today 9 PM'),
      );
    });

    test('tomorrow rolls over the month and the year', () {
      final presets = sendLaterPresets(DateTime(2026, 12, 31, 23, 30));
      expect(presets[0].at, DateTime(2027, 1, 1, 0, 30));
      expect(presets[1].at, DateTime(2027, 1, 1, 9));
    });

    test('every preset is a time the server takes', () {
      for (final hour in [0, 9, 19, 20, 23]) {
        final now = DateTime(2026, 10, 11, hour, 59, 59);
        for (final preset in sendLaterPresets(now)) {
          expect(
            sendLaterTimeAllowed(preset.at, now),
            isTrue,
            reason: '${preset.label} at $hour:59',
          );
        }
      }
    });
  });

  test('sendLaterTimeAllowed: a minute ahead to 120 days', () {
    final now = DateTime(2026, 10, 11, 12);
    bool ok(Duration ahead) => sendLaterTimeAllowed(now.add(ahead), now);
    expect(ok(const Duration(seconds: -1)), isFalse);
    expect(ok(const Duration(seconds: 59)), isFalse);
    expect(ok(const Duration(minutes: 1)), isTrue);
    expect(ok(const Duration(days: 120)), isTrue);
    expect(ok(const Duration(days: 120, minutes: 1)), isFalse);
  });

  test('formatSendAt names the day', () {
    final now = DateTime(2026, 10, 11, 12);
    String at(DateTime t) => formatSendAt(t, now: now);
    expect(at(DateTime(2026, 10, 11, 21)), 'Today 9:00 PM');
    expect(at(DateTime(2026, 10, 12, 9)), 'Tomorrow 9:00 AM');
    expect(at(DateTime(2026, 10, 14, 9, 5)), 'Wed 9:05 AM');
    expect(at(DateTime(2026, 11, 20, 18, 30)), '20 Nov, 6:30 PM');
    expect(at(DateTime(2027, 1, 5, 8)), '5 Jan 2027, 8:00 AM');
  });
}
