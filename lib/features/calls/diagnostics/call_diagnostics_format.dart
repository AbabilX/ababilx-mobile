import 'call_audio_health.dart';
import 'call_connection_path.dart';

/// Words for the developer panel. English only, like the rest of a screen no
/// user sees. A figure that was not measured says so; it is never drawn as 0.
const notMeasured = 'n/a';

bool _unknown(num? value) => value == null || !value.isFinite;

String formatMs(num? ms) => _unknown(ms) ? notMeasured : '${ms!.round()} ms';

String formatPercent(num? percent) =>
    _unknown(percent) ? notMeasured : '${percent!.toStringAsFixed(1)} %';

String formatBitrate(num? bps) =>
    _unknown(bps) ? notMeasured : '${(bps! / 1000).round()} kbps';

String formatCount(num? count) => _unknown(count) ? notMeasured : '$count';

String pathLabel(CallConnectionPath path) {
  final label = switch (path.kind) {
    CallPathKind.direct => 'P2P',
    CallPathKind.relay => 'TURN relay',
    CallPathKind.unknown => 'Unknown',
  };
  if (path.kind == CallPathKind.unknown || path.confirmedByTransport) {
    return label;
  }
  return '$label (unconfirmed)';
}

String transportLabel(CallConnectionPath path) {
  final protocol = path.protocol?.toUpperCase();
  if (protocol == null) return notMeasured;
  final relay = path.relayProtocol?.toUpperCase();
  return relay == null ? protocol : '$protocol (to TURN: $relay)';
}

String candidatesLabel(CallConnectionPath path) =>
    '${path.localType ?? notMeasured} → ${path.remoteType ?? notMeasured}';

String healthLabel(CallAudioHealth health) => switch (health) {
  CallAudioHealth.settling => 'Settling',
  CallAudioHealth.healthy => 'Healthy',
  CallAudioHealth.networkLoss => 'Network packet loss',
  CallAudioHealth.lateAudio => 'Late audio (jitter)',
  CallAudioHealth.pipelineInterruption => 'Audio pipeline interruption',
  CallAudioHealth.concealment => 'Concealing, cause unknown',
  CallAudioHealth.packetStall => 'Inbound packets stalled',
  CallAudioHealth.inboundSilent => 'Peer not sending (muted?), path alive',
  CallAudioHealth.noIncomingAudio => 'No incoming audio',
  CallAudioHealth.statsUnavailable => 'Statistics unavailable',
};
