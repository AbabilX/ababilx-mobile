import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'call_network_quality.dart';

/// Reads one [CallNetworkSample] out of each WebRTC stats report.
///
/// Packet counters in a report are totals since the call began, so loss is
/// worked out against the previous report: the share lost in the last
/// interval, not the call's lifetime average, which would hide a path that
/// has just gone bad behind ten good minutes.
class CallNetworkStatsReader {
  num? _received;
  num? _lost;

  CallNetworkSample read(List<StatsReport> stats) {
    num received = 0;
    num lost = 0;
    var sawInbound = false;
    double? jitterMs;
    double? remoteLoss;
    double? rttMs;

    for (final report in stats) {
      final v = report.values;
      switch (report.type) {
        case 'inbound-rtp':
          final got = _num(v['packetsReceived']);
          if (got == null) break;
          sawInbound = true;
          received += got;
          lost += _num(v['packetsLost']) ?? 0;
          if ((v['kind'] ?? v['mediaType']) == 'audio') {
            final jitter = _num(v['jitter']);
            if (jitter != null) jitterMs = jitter * 1000;
          }
        case 'remote-inbound-rtp':
          // What the other side says it lost of ours: the upload half.
          final fraction = _num(v['fractionLost']);
          if (fraction != null && fraction * 100 > (remoteLoss ?? 0)) {
            remoteLoss = fraction * 100;
          }
      }
    }

    final rtt = _num(selectedCandidatePair(stats)?['currentRoundTripTime']);
    if (rtt != null && rtt > 0) rttMs = rtt * 1000;

    double? inboundLoss;
    final beforeReceived = _received;
    final beforeLost = _lost;
    if (sawInbound) {
      if (beforeReceived != null && beforeLost != null) {
        final gotNow = received - beforeReceived;
        // The lost total can step back when a late packet turns up.
        final lostNow = lost - beforeLost < 0 ? 0 : lost - beforeLost;
        if (gotNow >= 0 && gotNow + lostNow > 0) {
          inboundLoss = lostNow * 100 / (gotNow + lostNow);
        }
      }
      _received = received;
      _lost = lost;
    }

    final loss = switch ((inboundLoss, remoteLoss)) {
      (null, null) => null,
      (final a?, null) => a,
      (null, final b?) => b,
      (final a?, final b?) => a > b ? a : b,
    };
    return CallNetworkSample(
      rttMs: rttMs,
      lossPercent: loss,
      jitterMs: jitterMs,
    );
  }

  static num? _num(Object? value) => statNum(value);
}

/// The candidate pair carrying the call, out of one stats report: the one
/// the transport names, else the one marked selected, else a nominated pair
/// that succeeded.
Map<dynamic, dynamic>? selectedCandidatePair(List<StatsReport> stats) {
  String? named;
  final pairs = <String, Map<dynamic, dynamic>>{};
  for (final report in stats) {
    if (report.type == 'transport') {
      final id = report.values['selectedCandidatePairId'];
      if (id is String && id.isNotEmpty) named = id;
    } else if (report.type == 'candidate-pair') {
      pairs[report.id] = report.values;
    }
  }
  final byName = pairs[named];
  if (byName != null) return byName;
  for (final pair in pairs.values) {
    if (pair['selected'] == true) return pair;
  }
  for (final pair in pairs.values) {
    if (pair['nominated'] == true && pair['state'] == 'succeeded') return pair;
  }
  return null;
}

/// Android hands numbers over as numbers, some platforms as strings.
num? statNum(Object? value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value);
  return null;
}
