import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../network/call_network_stats.dart';

/// Says when one stats report shows the call working again, for a recovery
/// that no connection-state event will end: a network change or a peer's
/// restart request can run start to finish with the state staying `connected`.
///
/// Incoming audio alone is not enough while we are sending: it shows the peer
/// reaches us, not that we reach the peer. A new report from the peer about
/// our stream shows both, and keeps working while the peer is muted. Incoming
/// audio only counts when there is nothing better to read: we send nothing
/// (muted, so the peer has nothing to report on) or the platform has no counter.
class VoiceMediaProof {
  Map<String, num> _inbound = {};
  num? _sent;
  num? _reports;

  bool update(List<StatsReport> stats) {
    final inbound = <String, num>{};
    num? sent;
    num? reports;
    for (final report in stats) {
      final v = report.values;
      if ((v['kind'] ?? v['mediaType']) != 'audio') continue;
      switch (report.type) {
        case 'inbound-rtp':
          final got = statNum(v['packetsReceived']);
          if (got != null) inbound[report.id] = got;
        case 'outbound-rtp':
          final out = statNum(v['packetsSent']);
          if (out != null) sent = (sent ?? 0) + out;
        case 'remote-inbound-rtp':
          final count = statNum(v['roundTripTimeMeasurements']);
          if (count != null) reports = (reports ?? 0) + count;
      }
    }

    final heard = inbound.entries.any((entry) {
      final previous = _inbound[entry.key];
      return previous != null && entry.value > previous;
    });
    final sending = _moved(_sent, sent);
    final reported = _moved(_reports, reports);
    final canReadReports = reports != null;
    _inbound = inbound;
    _sent = sent;
    _reports = reports;

    if (reported) return true;
    return heard && (!sending || !canReadReports);
  }

  /// A failed read: the next report has nothing to compare with.
  void reset() {
    _inbound = {};
    _sent = null;
    _reports = null;
  }

  static bool _moved(num? before, num? now) =>
      before != null && now != null && now > before;
}

/// Whether both the connection and ICE call the path up. While either does
/// not, media still arriving is one-way or stale, and no later state event
/// would restart a recovery that ended on it.
bool mediaPathUp(
  RTCPeerConnectionState? connection,
  RTCIceConnectionState? ice,
) =>
    connection == RTCPeerConnectionState.RTCPeerConnectionStateConnected &&
    (ice == RTCIceConnectionState.RTCIceConnectionStateConnected ||
        ice == RTCIceConnectionState.RTCIceConnectionStateCompleted);
