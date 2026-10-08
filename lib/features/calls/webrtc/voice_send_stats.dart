import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../network/call_network_stats.dart';

/// What this phone is sending on a 1:1 call, from one WebRTC stats report.
/// A null field could not be read this time.
class VoiceSendSample {
  const VoiceSendSample({
    this.audioBps,
    this.videoBps,
    this.audioTargetBps,
    this.videoTargetBps,
    this.availableBps,
    this.videoLimit,
  });

  /// Payload actually sent since the previous report.
  final int? audioBps;
  final int? videoBps;

  /// What WebRTC's allocator told each encoder to aim for.
  final int? audioTargetBps;
  final int? videoTargetBps;

  /// WebRTC's own estimate of what the path can carry outwards.
  final int? availableBps;

  /// Why the video encoder is holding quality back, when it is.
  final String? videoLimit;

  /// One log line: `sent/target` per lane, then the estimate, in kbps.
  String describe() {
    String k(int? bps) => bps == null ? '?' : '${(bps / 1000).round()}';
    final limit = videoLimit == null || videoLimit == 'none'
        ? ''
        : ' limit=$videoLimit';
    return 'audio=${k(audioBps)}/${k(audioTargetBps)}kbps '
        'video=${k(videoBps)}/${k(videoTargetBps)}kbps '
        'est=${k(availableBps)}kbps$limit';
  }
}

/// Reads a [VoiceSendSample] out of each stats report.
///
/// Byte counters are totals since the call began, so a rate is the step from
/// the previous report over the time between the two.
class VoiceSendStatsReader {
  Map<String, num> _bytes = const {};
  int? _atMs;

  VoiceSendSample read(List<StatsReport> stats, {required int nowMs}) {
    final before = _atMs;
    final elapsedMs = before == null ? 0 : nowMs - before;
    final bytes = <String, num>{};
    final sent = <String, num>{};
    final target = <String, num>{};
    String? limit;

    for (final report in stats) {
      if (report.type != 'outbound-rtp') continue;
      final v = report.values;
      final kind = v['kind'] ?? v['mediaType'];
      if (kind is! String) continue;
      final total = statNum(v['bytesSent']);
      if (total != null) {
        bytes[report.id] = total;
        final previous = _bytes[report.id];
        // A counter that steps back belongs to a new stream: no rate yet.
        if (previous != null && elapsedMs > 0 && total >= previous) {
          sent[kind] =
              (sent[kind] ?? 0) + (total - previous) * 8000 / elapsedMs;
        }
      }
      final aim = statNum(v['targetBitrate']);
      if (aim != null) target[kind] = (target[kind] ?? 0) + aim;
      final reason = v['qualityLimitationReason'];
      if (kind == 'video' && reason is String) limit ??= reason;
    }
    _bytes = bytes;
    _atMs = nowMs;

    final available = statNum(
      selectedCandidatePair(stats)?['availableOutgoingBitrate'],
    );
    return VoiceSendSample(
      audioBps: sent['audio']?.round(),
      videoBps: sent['video']?.round(),
      audioTargetBps: target['audio']?.round(),
      videoTargetBps: target['video']?.round(),
      availableBps: available == null || available <= 0
          ? null
          : available.round(),
      videoLimit: limit,
    );
  }
}
