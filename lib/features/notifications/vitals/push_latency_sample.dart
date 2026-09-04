/// One push, and how long it took to reach the phone.
///
/// [latency] is FCM's own `sentTime` subtracted from the moment the background
/// isolate woke — so it measures the gap the user actually feels, not any
/// server-side delay before the push was handed to Google.
class PushLatencySample {
  const PushLatencySample({required this.receivedAt, required this.latency});

  factory PushLatencySample.fromJson(Map<String, dynamic> json) =>
      PushLatencySample(
        receivedAt: DateTime.fromMillisecondsSinceEpoch(
          int.tryParse(json['at']?.toString() ?? '') ?? 0,
        ),
        latency: Duration(
          milliseconds: int.tryParse(json['ms']?.toString() ?? '') ?? 0,
        ),
      );

  final DateTime receivedAt;
  final Duration latency;

  Map<String, dynamic> toJson() => {
    'at': receivedAt.millisecondsSinceEpoch,
    'ms': latency.inMilliseconds,
  };
}
