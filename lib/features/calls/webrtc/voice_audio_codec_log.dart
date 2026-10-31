import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../voice_call_log.dart';

/// The `a=fmtp` parameters of Opus in [sdp] — what the side that wrote the
/// description asks to RECEIVE. Empty when Opus is offered without any; null
/// when there is no Opus line at all.
String? opusFmtp(String? sdp) {
  if (sdp == null || sdp.isEmpty) return null;
  final payload = RegExp(
    r'^a=rtpmap:(\d+) opus/',
    multiLine: true,
    caseSensitive: false,
  ).firstMatch(sdp)?.group(1);
  if (payload == null) return null;
  return RegExp(
        '^a=fmtp:$payload (.*?)\\r?\$',
        multiLine: true,
      ).firstMatch(sdp)?.group(1) ??
      '';
}

/// Whether the audio section of [sdp] carries transport-wide congestion
/// feedback. Agreed by both sides, it puts the voice inside WebRTC's send
/// estimate, which is what lets its bitrate follow the link.
bool audioHasTransportCc(String? sdp) {
  if (sdp == null) return false;
  for (final section in sdp.split(RegExp(r'(?=^m=)', multiLine: true))) {
    if (section.startsWith('m=audio ')) {
      return section.contains('transport-wide-cc') ||
          section.contains(' transport-cc');
    }
  }
  return false;
}

/// The codec the outgoing voice is really encoded with, as WebRTC reports it.
String? audioCodecInUse(List<StatsReport> stats) {
  String? codecId;
  for (final report in stats) {
    final v = report.values;
    if (report.type == 'outbound-rtp' &&
        (v['kind'] ?? v['mediaType']) == 'audio' &&
        v['codecId'] is String) {
      codecId = v['codecId'] as String;
    }
  }
  return _codecNamed(stats, codecId);
}

/// The codec the incoming voice arrives in; the far side's encoder chose it,
/// so it need not match [audioCodecInUse].
String? inboundAudioCodec(List<StatsReport> stats) {
  for (final report in stats) {
    final v = report.values;
    if (report.type == 'inbound-rtp' &&
        (v['kind'] ?? v['mediaType']) == 'audio' &&
        v['codecId'] is String) {
      return _codecNamed(stats, v['codecId'] as String);
    }
  }
  return null;
}

String? _codecNamed(List<StatsReport> stats, String? codecId) {
  if (codecId == null) return null;
  for (final report in stats) {
    if (report.id != codecId) continue;
    final v = report.values;
    if (v['mimeType'] is! String) return null;
    return '${v['mimeType']} ${v['sdpFmtpLine'] ?? ''}'.trim();
  }
  return null;
}

/// One line saying how the voice was negotiated. `send` is what the far side
/// asked for and our encoder obeys; `recv` is what we asked of theirs. Never
/// throws.
Future<void> logAudioCodec(
  RTCPeerConnection peer,
  List<StatsReport> stats,
) async {
  try {
    final local = (await peer.getLocalDescription())?.sdp;
    final remote = (await peer.getRemoteDescription())?.sdp;
    final feedback = audioHasTransportCc(local) && audioHasTransportCc(remote);
    voiceCallLog(
      'audio.opus',
      reason:
          'send=[${opusFmtp(remote) ?? 'none'}] '
          'recv=[${opusFmtp(local) ?? 'none'}] '
          'transportCc=$feedback '
          'inUse=[${audioCodecInUse(stats) ?? 'unknown'}]',
    );
  } catch (error) {
    voiceCallLog('audio.opus.failed', reason: error.toString());
  }
}
