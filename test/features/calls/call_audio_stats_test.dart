import 'package:ababilx/features/calls/diagnostics/call_audio_stats.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

StatsReport _inbound({
  String id = 'ia',
  String kind = 'audio',
  Object? received = 0,
  Object? lost = 0,
  Object? bytes = 0,
  Object? jitter = 0.02,
  Object? delay = 0.0,
  Object? emitted = 0,
  Object? concealed = 0,
  Object? silent = 0,
  Object? events = 0,
  Object? samples = 0,
  Object? duration = 0.0,
  Object? level = 0.1,
}) => StatsReport(id, 'inbound-rtp', 0, {
  'kind': kind,
  'packetsReceived': received,
  'packetsLost': lost,
  'bytesReceived': bytes,
  'jitter': jitter,
  'jitterBufferDelay': delay,
  'jitterBufferEmittedCount': emitted,
  'concealedSamples': concealed,
  'silentConcealedSamples': silent,
  'concealmentEvents': events,
  'totalSamplesReceived': samples,
  'totalSamplesDuration': duration,
  'audioLevel': level,
});

StatsReport _outbound({
  String id = 'oa',
  String kind = 'audio',
  Object? bytes = 0,
  Object? packets = 0,
  Object? retransmitted,
}) => StatsReport(id, 'outbound-rtp', 0, {
  'kind': kind,
  'bytesSent': bytes,
  'packetsSent': packets,
  'retransmittedPacketsSent': ?retransmitted,
});

void main() {
  group('audio only', () {
    test('video reports never reach the audio numbers', () {
      final reader = CallAudioStatsReader()
        ..read([
          _inbound(received: 100, lost: 0),
          _inbound(id: 'iv', kind: 'video', received: 1000, lost: 0),
        ], nowMs: 0);
      final sample = reader.read([
        _inbound(received: 200, lost: 0),
        _inbound(id: 'iv', kind: 'video', received: 2000, lost: 500),
      ], nowMs: 2000);
      expect(sample.lossPercent, 0);
      expect(sample.packetsReceivedDelta, 100);
    });

    test('a report with no kind is not taken for audio', () {
      final sample = CallAudioStatsReader().read([
        StatsReport('x', 'inbound-rtp', 0, {'packetsReceived': 9}),
      ], nowMs: 0);
      expect(sample.hasInbound, isFalse);
    });

    test('mediaType is read where kind is absent', () {
      final sample = CallAudioStatsReader().read([
        StatsReport('x', 'inbound-rtp', 0, {
          'mediaType': 'audio',
          'packetsReceived': 9,
        }),
      ], nowMs: 0);
      expect(sample.hasInbound, isTrue);
      expect(sample.packetsReceived, 9);
    });
  });

  group('interval calculations', () {
    test('the first report has totals and no interval figures', () {
      final sample = CallAudioStatsReader().read([
        _inbound(received: 100, lost: 5, bytes: 1000),
        _outbound(bytes: 500, packets: 10),
      ], nowMs: 0);
      expect(sample.packetsReceived, 100);
      expect(sample.packetsLost, 5);
      expect(sample.packetsSent, 10);
      expect(sample.lossPercent, isNull);
      expect(sample.inboundBps, isNull);
      expect(sample.outboundBps, isNull);
      expect(sample.jitterBufferDelayMs, isNull);
      expect(sample.concealmentPercent, isNull);
    });

    test('loss is the share lost in this interval, not the lifetime', () {
      final reader = CallAudioStatsReader()
        ..read([_inbound(received: 1000, lost: 500)], nowMs: 0);
      final sample = reader.read([
        _inbound(received: 1090, lost: 510),
      ], nowMs: 2000);
      expect(sample.lossPercent, 10);
    });

    test('a lost total stepping back reads as no loss', () {
      final reader = CallAudioStatsReader()
        ..read([_inbound(received: 100, lost: 10)], nowMs: 0);
      final sample = reader.read([
        _inbound(received: 150, lost: 8),
      ], nowMs: 2000);
      expect(sample.lossPercent, 0);
    });

    test('bitrates are the byte step over the elapsed time', () {
      final reader = CallAudioStatsReader()
        ..read([_inbound(bytes: 1000), _outbound(bytes: 1000)], nowMs: 1000);
      final sample = reader.read([
        _inbound(bytes: 9000),
        _outbound(bytes: 5000),
      ], nowMs: 3000);
      expect(sample.inboundBps, 32000);
      expect(sample.outboundBps, 16000);
    });

    test('jitter is reported in milliseconds', () {
      final sample = CallAudioStatsReader().read([
        _inbound(jitter: 0.025),
      ], nowMs: 0);
      expect(sample.jitterMs, 25);
    });

    test('jitter buffer delay is delay over emitted samples', () {
      final reader = CallAudioStatsReader()
        ..read([_inbound(delay: 10.0, emitted: 48000)], nowMs: 0);
      final sample = reader.read([
        _inbound(delay: 9610.0, emitted: 144000),
      ], nowMs: 2000);
      expect(sample.jitterBufferDelayMs, closeTo(100, 0.001));
    });

    test('concealment leaves out silence, which nobody can hear', () {
      final reader = CallAudioStatsReader()
        ..read([
          _inbound(concealed: 100, silent: 100, samples: 1000, events: 1),
        ], nowMs: 0);
      final sample = reader.read([
        _inbound(concealed: 10100, silent: 5100, samples: 101000, events: 4),
      ], nowMs: 2000);
      expect(sample.concealmentPercent, 5);
      expect(sample.concealmentEventsDelta, 3);
    });

    test('playout share is the audio played over the time passed', () {
      final reader = CallAudioStatsReader()
        ..read([_inbound(duration: 10.0)], nowMs: 0);
      final sample = reader.read([_inbound(duration: 11.0)], nowMs: 2000);
      expect(sample.playoutShare, 0.5);
    });

    test('retransmits are a step, absent when never reported', () {
      final reader = CallAudioStatsReader()
        ..read([_outbound(retransmitted: 4)], nowMs: 0);
      expect(
        reader.read([
          _outbound(retransmitted: 9),
        ], nowMs: 2000).retransmittedDelta,
        5,
      );
      expect(
        CallAudioStatsReader().read([_outbound()], nowMs: 0).retransmittedDelta,
        isNull,
      );
    });

    test('no time passed gives no rate', () {
      final reader = CallAudioStatsReader()
        ..read([_inbound(bytes: 100)], nowMs: 5);
      expect(reader.read([_inbound(bytes: 900)], nowMs: 5).inboundBps, isNull);
    });
  });

  group('counter resets', () {
    test('a new stream id starts over instead of producing a jump', () {
      final reader = CallAudioStatsReader()
        ..read([_inbound(received: 5000, lost: 400, bytes: 90000)], nowMs: 0);
      final sample = reader.read([
        _inbound(id: 'ia2', received: 10, lost: 0, bytes: 100),
      ], nowMs: 2000);
      expect(sample.packetsReceivedDelta, isNull);
      expect(sample.lossPercent, isNull);
      expect(sample.inboundBps, isNull);
    });

    test('the same id with a smaller total is a reset, not negative', () {
      final reader = CallAudioStatsReader()
        ..read([_inbound(received: 500, lost: 40, bytes: 9000)], nowMs: 0);
      final reset = reader.read([
        _inbound(received: 5, lost: 0, bytes: 90),
      ], nowMs: 2000);
      expect(reset.packetsReceivedDelta, isNull);
      expect(reset.lossPercent, isNull);
      expect(reset.inboundBps, isNull);
      final next = reader.read([
        _inbound(received: 15, lost: 0, bytes: 890),
      ], nowMs: 4000);
      expect(next.packetsReceivedDelta, 10);
      expect(next.inboundBps, 3200);
    });

    test(
      'an old stream beside a new one still counts only with a baseline',
      () {
        final reader = CallAudioStatsReader()
          ..read([_inbound(received: 100, bytes: 1000)], nowMs: 0);
        final sample = reader.read([
          _inbound(received: 150, bytes: 2000),
          _inbound(id: 'ia2', received: 9000, bytes: 900000),
        ], nowMs: 2000);
        expect(sample.packetsReceivedDelta, 50);
        expect(sample.inboundBps, 4000);
      },
    );
  });

  group('missing statistics', () {
    test('an empty report is no audio at all, not a crash', () {
      final sample = CallAudioStatsReader().read(const [], nowMs: 0);
      expect(sample.hasInbound, isFalse);
      expect(sample.hasOutbound, isFalse);
      expect(sample.missingInboundFields, isEmpty);
    });

    test('fields a platform does not report are named and stay null', () {
      final reader = CallAudioStatsReader();
      StatsReport bare(int got) => StatsReport('ia', 'inbound-rtp', 0, {
        'kind': 'audio',
        'packetsReceived': got,
      });
      reader.read([bare(1)], nowMs: 0);
      final sample = reader.read([bare(9)], nowMs: 2000);
      expect(sample.packetsReceivedDelta, 8);
      expect(sample.jitterMs, isNull);
      expect(sample.concealmentPercent, isNull);
      expect(sample.jitterBufferDelayMs, isNull);
      expect(sample.audioLevel, isNull);
      expect(
        sample.missingInboundFields,
        containsAll(['concealedSamples', 'jitterBufferDelay', 'audioLevel']),
      );
      expect(sample.missingInboundFields, isNot(contains('packetsReceived')));
    });

    test('a value of the wrong shape counts as missing', () {
      final sample = CallAudioStatsReader().read([
        _inbound(jitter: 'not a number', level: const ['x']),
      ], nowMs: 0);
      expect(sample.jitterMs, isNull);
      expect(sample.audioLevel, isNull);
      expect(
        sample.missingInboundFields,
        containsAll(['jitter', 'audioLevel']),
      );
    });

    test('NaN, Infinity and negatives count as missing, never as figures', () {
      for (final junk in <Object>['NaN', 'Infinity', double.nan, -5]) {
        final reader = CallAudioStatsReader()
          ..read([_inbound(received: 1, bytes: 1, jitter: junk)], nowMs: 0);
        final sample = reader.read([
          _inbound(received: junk, bytes: junk, jitter: junk, level: junk),
        ], nowMs: 2000);
        expect(sample.jitterMs, isNull);
        expect(sample.audioLevel, isNull);
        expect(sample.packetsReceived, isNull);
        expect(sample.inboundBps, isNull);
      }
    });

    test('a negative lost total is legal: duplicates can outnumber losses', () {
      final sample = CallAudioStatsReader().read([
        _inbound(received: 10, lost: -2),
      ], nowMs: 0);
      expect(sample.packetsLost, -2);
    });

    test('a byte total too big for a rate does not wrap negative', () {
      final reader = CallAudioStatsReader()
        ..read([_inbound(bytes: 0)], nowMs: 0);
      final sample = reader.read([
        _inbound(bytes: 9007199254740993),
      ], nowMs: 2000);
      expect(sample.inboundBps, greaterThan(0));
    });

    test('numbers handed over as strings are read', () {
      final sample = CallAudioStatsReader().read([
        _inbound(received: '42', jitter: '0.01'),
      ], nowMs: 0);
      expect(sample.packetsReceived, 42);
      expect(sample.jitterMs, 10);
    });
  });

  group('the transport', () {
    StatsReport transport(Object? packets) =>
        StatsReport('tr', 'transport', 0, {'packetsReceived': packets});

    test('its packets are stepped, though it has no kind', () {
      final reader = CallAudioStatsReader()..read([transport(10)], nowMs: 0);
      expect(
        reader.read([transport(14)], nowMs: 2000).transportPacketsDelta,
        4,
      );
    });

    test('a platform without the field reads as unknown', () {
      final reader = CallAudioStatsReader()..read([transport(null)], nowMs: 0);
      expect(
        reader.read([transport(null)], nowMs: 2000).transportPacketsDelta,
        isNull,
      );
    });
  });

  group('the far side', () {
    test('remote loss reads audio reports and ignores video', () {
      final sample = CallAudioStatsReader().read([
        StatsReport('ra', 'remote-inbound-rtp', 0, {
          'kind': 'audio',
          'fractionLost': 0.02,
        }),
        StatsReport('rv', 'remote-inbound-rtp', 0, {
          'kind': 'video',
          'fractionLost': 0.5,
        }),
      ], nowMs: 0);
      expect(sample.remoteLossPercent, 2);
    });
  });

  group('codecs', () {
    test('each direction names the codec its own report points at', () {
      final sample = CallAudioStatsReader().read([
        StatsReport('ia', 'inbound-rtp', 0, {
          'kind': 'audio',
          'packetsReceived': 1,
          'codecId': 'cr',
        }),
        StatsReport('oa', 'outbound-rtp', 0, {
          'kind': 'audio',
          'bytesSent': 1,
          'codecId': 'cs',
        }),
        StatsReport('cr', 'codec', 0, {'mimeType': 'audio/opus'}),
        StatsReport('cs', 'codec', 0, {'mimeType': 'audio/red'}),
      ], nowMs: 0);
      expect(sample.inboundCodec, 'audio/opus');
      expect(sample.outboundCodec, 'audio/red');
    });

    test('a codec id with no codec report is unknown', () {
      final sample = CallAudioStatsReader().read([
        StatsReport('ia', 'inbound-rtp', 0, {
          'kind': 'audio',
          'packetsReceived': 1,
          'codecId': 'gone',
        }),
      ], nowMs: 0);
      expect(sample.inboundCodec, isNull);
    });
  });
}
