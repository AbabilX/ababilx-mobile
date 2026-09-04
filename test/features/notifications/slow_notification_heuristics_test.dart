import 'package:ababilx/features/notifications/vitals/push_latency_sample.dart';
import 'package:ababilx/features/notifications/vitals/slow_notification_heuristics.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 9, 4, 12);

/// [count] pushes spread back over [spread], each late by [latency].
List<PushLatencySample> _samples({
  required int count,
  required Duration latency,
  Duration spread = const Duration(days: 4),
}) => List.generate(
  count,
  (i) => PushLatencySample(
    receivedAt: _now.subtract(spread * ((i + 1) / count)),
    latency: latency,
  ),
);

void main() {
  group('percentileLatency', () {
    test('no samples has no percentile', () {
      expect(percentileLatency(const [], 50), Duration.zero);
    });

    test('nearest rank, not an average', () {
      final samples = [
        for (final minutes in [1, 2, 3, 100])
          PushLatencySample(
            receivedAt: _now,
            latency: Duration(minutes: minutes),
          ),
      ];
      expect(percentileLatency(samples, 50), const Duration(minutes: 2));
      expect(percentileLatency(samples, 100), const Duration(minutes: 100));
    });
  });

  group('isHavingDelayedNotifications', () {
    test('a fresh install has nothing to say', () {
      expect(isHavingDelayedNotifications(const [], _now), isFalse);
    });

    test('slow pushes still need the sample floor', () {
      final samples = _samples(count: 10, latency: const Duration(hours: 6));
      expect(hasEnoughLatencyData(samples, _now), isFalse);
      expect(isHavingDelayedNotifications(samples, _now), isFalse);
    });

    test('one bad day is not a pattern', () {
      final samples = _samples(
        count: 80,
        latency: const Duration(hours: 6),
        spread: const Duration(hours: 20),
      );
      expect(hasEnoughLatencyData(samples, _now), isFalse);
      expect(isHavingDelayedNotifications(samples, _now), isFalse);
    });

    test('prompt pushes over a long window say nothing is wrong', () {
      final samples = _samples(count: 80, latency: const Duration(seconds: 4));
      expect(hasEnoughLatencyData(samples, _now), isTrue);
      expect(isHavingDelayedNotifications(samples, _now), isFalse);
    });

    test('most pushes late by an hour trips the median', () {
      final samples = [
        ..._samples(count: 60, latency: const Duration(hours: 1)),
        ..._samples(count: 20, latency: const Duration(seconds: 4)),
      ];
      expect(percentileLatency(samples, 50), const Duration(hours: 1));
      expect(isHavingDelayedNotifications(samples, _now), isTrue);
    });

    test('a slow tail trips p90 even with a healthy median', () {
      final samples = [
        ..._samples(count: 70, latency: const Duration(seconds: 4)),
        ..._samples(count: 20, latency: const Duration(hours: 5)),
      ];
      expect(percentileLatency(samples, 50), const Duration(seconds: 4));
      expect(isHavingDelayedNotifications(samples, _now), isTrue);
    });
  });
}
