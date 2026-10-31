import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../network/call_network_stats.dart';
import '../webrtc/voice_audio_codec_log.dart';
import 'call_audio_sample.dart';

export 'call_audio_sample.dart';

/// Reads a [CallAudioSample] out of each stats report.
///
/// Every counter is a total, so each is stepped against the same stream's
/// previous value. A stream with no previous value, or a total that went down
/// (a new SSRC after an ICE restart, a reset), gives no step for this
/// interval and becomes the new baseline, instead of a jump.
class CallAudioStatsReader {
  static const _inboundFields = [
    'packetsReceived',
    'packetsLost',
    'bytesReceived',
    'jitter',
    'jitterBufferDelay',
    'jitterBufferEmittedCount',
    'concealedSamples',
    'concealmentEvents',
    'totalSamplesReceived',
    'totalSamplesDuration',
    'audioLevel',
  ];

  Map<String, num> _before = const {};
  int? _atMs;

  CallAudioSample read(List<StatsReport> stats, {required int nowMs}) {
    final previous = _before;
    final now = <String, num>{};
    final elapsedMs = _atMs == null ? 0 : nowMs - _atMs!;

    num? step(String stream, String field, Object? raw) {
      final value = _stat(raw);
      if (value == null) return null;
      final key = '$stream/$field';
      now[key] = value;
      final before = previous[key];
      return before == null || value < before ? null : value - before;
    }

    var hasInbound = false, hasOutbound = false;
    num? received, lost, sent, gotDelta, gotForLoss, lostForLoss;
    num? delayStep, emittedStep, concealedStep, samplesStep, eventsStep;
    num? playedStep, inBytes, outBytes, retransmitted, transportStep;
    double? jitterMs, level, remoteLoss;
    final missing = <String>{};

    for (final report in stats) {
      final v = report.values;
      if (report.type == 'transport') {
        transportStep = _plus(
          transportStep,
          step(report.id, 'transport', v['packetsReceived']),
        );
        continue;
      }
      if ((v['kind'] ?? v['mediaType']) != 'audio') continue;
      final id = report.id;
      switch (report.type) {
        case 'inbound-rtp':
          hasInbound = true;
          for (final field in _inboundFields) {
            if (_stat(v[field]) == null) missing.add(field);
          }
          received = _plus(received, _stat(v['packetsReceived']));
          lost = _plus(lost, _signedStat(v['packetsLost']));
          final got = step(id, 'received', v['packetsReceived']);
          final gone = _signedStat(v['packetsLost']);
          final lostBefore = previous['$id/lost'];
          if (gone != null) now['$id/lost'] = gone;
          gotDelta = _plus(gotDelta, got);
          if (got != null && gone != null && lostBefore != null) {
            // The lost total steps back when a late packet turns up.
            final lostNow = gone < lostBefore ? 0 : gone - lostBefore;
            gotForLoss = _plus(gotForLoss, got);
            lostForLoss = _plus(lostForLoss, lostNow);
          }
          inBytes = _plus(inBytes, step(id, 'bytes', v['bytesReceived']));
          final delay = step(id, 'delay', v['jitterBufferDelay']);
          final emitted = step(id, 'emitted', v['jitterBufferEmittedCount']);
          if (delay != null && emitted != null) {
            delayStep = _plus(delayStep, delay);
            emittedStep = _plus(emittedStep, emitted);
          }
          final concealed = step(id, 'concealed', v['concealedSamples']);
          final silent = step(id, 'silent', v['silentConcealedSamples']);
          final samples = step(id, 'samples', v['totalSamplesReceived']);
          if (concealed != null && samples != null) {
            final audible = concealed - (silent ?? 0);
            concealedStep = _plus(concealedStep, audible < 0 ? 0 : audible);
            samplesStep = _plus(samplesStep, samples);
          }
          eventsStep = _plus(
            eventsStep,
            step(id, 'events', v['concealmentEvents']),
          );
          playedStep = _plus(
            playedStep,
            step(id, 'played', v['totalSamplesDuration']),
          );
          final jitter = _stat(v['jitter']);
          if (jitter != null) jitterMs = _finite(jitter * 1000)?.toDouble();
          level = _stat(v['audioLevel'])?.toDouble() ?? level;
        case 'outbound-rtp':
          hasOutbound = true;
          sent = _plus(sent, _stat(v['packetsSent']));
          outBytes = _plus(outBytes, step(id, 'sent', v['bytesSent']));
          retransmitted = _plus(
            retransmitted,
            step(id, 'retransmitted', v['retransmittedPacketsSent']),
          );
        case 'remote-inbound-rtp':
          final fraction = _stat(v['fractionLost']);
          if (fraction != null && fraction * 100 > (remoteLoss ?? -1)) {
            remoteLoss = fraction * 100;
          }
      }
    }
    _before = now;
    _atMs = nowMs;

    double? share(num? part, num? whole, double scale) =>
        part == null || whole == null || whole <= 0
        ? null
        : _finite(part * scale / whole)?.toDouble();
    int? bps(num? bytes) => bytes == null || elapsedMs <= 0
        ? null
        : _finite(bytes.toDouble() * 8000 / elapsedMs)?.round();

    return CallAudioSample(
      hasInbound: hasInbound,
      hasOutbound: hasOutbound,
      packetsReceived: _finite(received)?.toInt(),
      packetsLost: _finite(lost)?.toInt(),
      packetsSent: _finite(sent)?.toInt(),
      packetsReceivedDelta: _finite(gotDelta)?.toInt(),
      transportPacketsDelta: _finite(transportStep)?.toInt(),
      lossPercent: share(lostForLoss, _plus(gotForLoss, lostForLoss), 100),
      remoteLossPercent: _finite(remoteLoss)?.toDouble(),
      jitterMs: jitterMs,
      jitterBufferDelayMs: share(delayStep, emittedStep, 1000),
      concealmentPercent: share(concealedStep, samplesStep, 100),
      concealmentEventsDelta: _finite(eventsStep)?.toInt(),
      playoutShare: share(playedStep, elapsedMs, 1000),
      audioLevel: level,
      inboundBps: bps(inBytes),
      outboundBps: bps(outBytes),
      retransmittedDelta: _finite(retransmitted)?.toInt(),
      inboundCodec: inboundAudioCodec(stats),
      outboundCodec: audioCodecInUse(stats),
      missingInboundFields: hasInbound ? missing.toList() : const [],
    );
  }

  static num? _plus(num? total, num? more) =>
      more == null ? total : (total ?? 0) + more;

  static num? _finite(num? value) =>
      value != null && value.isFinite ? value : null;

  /// A native side can hand over anything, `NaN` and `Infinity` included, and
  /// `num.tryParse` accepts both. Only `packetsLost` may be below zero.
  static num? _signedStat(Object? raw) => _finite(statNum(raw));

  static num? _stat(Object? raw) {
    final value = _signedStat(raw);
    return value == null || value < 0 ? null : value;
  }
}
