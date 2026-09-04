import 'push_latency_sample.dart';

/// When a run of push latencies counts as "this phone is holding notifications".
///
/// The numbers are Signal's (`SlowNotificationHeuristics`), kept as they are
/// rather than guessed at: half the pushes late by half an hour, or a tenth of
/// them late by two hours, over a window long enough to be a pattern instead of
/// one bad night. Loosening any of these buys a prompt the user did not earn.
class SlowNotificationConfig {
  const SlowNotificationConfig({
    this.minimumWindow = const Duration(days: 3),
    this.minimumSamples = 50,
    this.percentiles = const {
      50: Duration(minutes: 30),
      90: Duration(hours: 2),
    },
  });

  /// How long we must have been watching before the samples mean anything.
  final Duration minimumWindow;

  /// How many pushes must be on record.
  final int minimumSamples;

  /// Percentile → the latency at that percentile that counts as too slow.
  final Map<int, Duration> percentiles;
}

/// Percentile of [samples] by latency. Zero for no samples.
///
/// The index is `floor(n * p / 100) - 1`, which is Signal's
/// `LocalMetricsDatabase.percentile` — integer arithmetic feeding a SQL
/// `OFFSET` over an ascending sort. Written out rather than rounded the
/// intuitive way so the two agree sample for sample.
Duration percentileLatency(List<PushLatencySample> samples, int percentile) {
  if (samples.isEmpty) return Duration.zero;
  final sorted = samples.map((s) => s.latency).toList()..sort();
  final offset = sorted.length * percentile.clamp(0, 100) ~/ 100 - 1;
  return sorted[offset.clamp(0, sorted.length - 1)];
}

/// Whether enough has been recorded, for long enough, to judge anything.
bool hasEnoughLatencyData(
  List<PushLatencySample> samples,
  DateTime now, {
  SlowNotificationConfig config = const SlowNotificationConfig(),
}) {
  if (samples.length < config.minimumSamples) return false;
  final oldest = samples
      .map((s) => s.receivedAt)
      .reduce((a, b) => a.isBefore(b) ? a : b);
  return !oldest.isAfter(now.subtract(config.minimumWindow));
}

/// Whether this phone looks like it is delivering pushes late.
///
/// Signal reaches the same conclusion from three signals — failed FCM service
/// starts, failed websocket queue drains, and message latency. Only the third
/// exists here: nothing in this app starts a service per push, and there is no
/// background socket to drain. So latency alone decides, which is why the
/// thresholds are not relaxed to compensate.
bool isHavingDelayedNotifications(
  List<PushLatencySample> samples,
  DateTime now, {
  SlowNotificationConfig config = const SlowNotificationConfig(),
}) {
  if (!hasEnoughLatencyData(samples, now, config: config)) return false;
  for (final entry in config.percentiles.entries) {
    if (percentileLatency(samples, entry.key) > entry.value) return true;
  }
  return false;
}
