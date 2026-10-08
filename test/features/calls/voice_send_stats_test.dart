import 'package:ababilx/features/calls/webrtc/voice_audio_codec_log.dart';
import 'package:ababilx/features/calls/webrtc/voice_send_stats.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

StatsReport _report(String id, String type, Map<String, dynamic> values) =>
    StatsReport(id, type, 0, values);

List<StatsReport> _stats({
  required int audioBytes,
  int? videoBytes,
  Object? estimate = 250000.0,
  String videoId = 'v',
}) => [
  _report('t', 'transport', {'selectedCandidatePairId': 'p'}),
  _report('p', 'candidate-pair', {'availableOutgoingBitrate': estimate}),
  _report('a', 'outbound-rtp', {
    'kind': 'audio',
    'bytesSent': audioBytes,
    'targetBitrate': 32000,
    'codecId': 'c',
  }),
  if (videoBytes != null)
    _report(videoId, 'outbound-rtp', {
      'kind': 'video',
      'bytesSent': videoBytes,
      'targetBitrate': 180000.0,
      'qualityLimitationReason': 'bandwidth',
    }),
  _report('c', 'codec', {
    'mimeType': 'audio/opus',
    'sdpFmtpLine': 'minptime=10;useinbandfec=1',
  }),
];

const _sdp =
    'v=0\r\n'
    'm=audio 9 UDP/TLS/RTP/SAVPF 111 63\r\n'
    'a=extmap:3 http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01\r\n'
    'a=rtpmap:111 opus/48000/2\r\n'
    'a=rtcp-fb:111 transport-cc\r\n'
    'a=fmtp:111 minptime=10;useinbandfec=1\r\n'
    'a=rtpmap:63 red/48000/2\r\n'
    'a=fmtp:63 111/111\r\n'
    'm=video 9 UDP/TLS/RTP/SAVPF 96\r\n'
    'a=rtpmap:96 VP8/90000\r\n';

void main() {
  group('send rates', () {
    test('the first report has totals but no rate yet', () {
      final sample = VoiceSendStatsReader().read(
        _stats(audioBytes: 1000, videoBytes: 5000),
        nowMs: 1000,
      );
      expect(sample.audioBps, isNull);
      expect(sample.videoBps, isNull);
      expect(sample.audioTargetBps, 32000);
      expect(sample.videoTargetBps, 180000);
      expect(sample.availableBps, 250000);
      expect(sample.videoLimit, 'bandwidth');
    });

    test('a rate is the step since the previous report', () {
      final reader = VoiceSendStatsReader()
        ..read(_stats(audioBytes: 1000, videoBytes: 5000), nowMs: 1000);
      final sample = reader.read(
        _stats(audioBytes: 9000, videoBytes: 55000),
        nowMs: 3000,
      );
      expect(sample.audioBps, 32000);
      expect(sample.videoBps, 200000);
      expect(
        sample.describe(),
        'audio=32/32kbps video=200/180kbps est=250kbps limit=bandwidth',
      );
    });

    test('a held camera reads as zero, a missing lane as unknown', () {
      final reader = VoiceSendStatsReader()
        ..read(_stats(audioBytes: 1000, videoBytes: 5000), nowMs: 1000);
      expect(
        reader
            .read(_stats(audioBytes: 9000, videoBytes: 5000), nowMs: 3000)
            .videoBps,
        0,
      );
      final audioOnly = reader.read(_stats(audioBytes: 17000), nowMs: 5000);
      expect(audioOnly.videoBps, isNull);
      expect(audioOnly.describe(), 'audio=32/32kbps video=?/?kbps est=250kbps');
    });

    test('a new stream or a counter that stepped back gives no rate', () {
      final reader = VoiceSendStatsReader()
        ..read(_stats(audioBytes: 9000, videoBytes: 5000), nowMs: 1000);
      final sample = reader.read(
        _stats(audioBytes: 100, videoBytes: 900, videoId: 'v2'),
        nowMs: 3000,
      );
      expect(sample.audioBps, isNull);
      expect(sample.videoBps, isNull);
    });

    test('an estimate may be a string, and zero is no estimate', () {
      final reader = VoiceSendStatsReader();
      expect(
        reader
            .read(_stats(audioBytes: 1, estimate: '61000'), nowMs: 1)
            .availableBps,
        61000,
      );
      expect(
        reader.read(_stats(audioBytes: 1, estimate: 0), nowMs: 2).availableBps,
        isNull,
      );
      expect(
        reader
            .read(_stats(audioBytes: 1, estimate: null), nowMs: 3)
            .availableBps,
        isNull,
      );
    });
  });

  group('negotiated voice', () {
    test('the Opus line is found by its own payload number', () {
      expect(opusFmtp(_sdp), 'minptime=10;useinbandfec=1');
      expect(opusFmtp(_sdp.replaceAll('\r\n', '\n')), isNotEmpty);
    });

    test('Opus without parameters is empty, no Opus is null', () {
      expect(opusFmtp('a=rtpmap:111 opus/48000/2\r\n'), '');
      expect(opusFmtp('m=audio 9 RTP/AVP 0\r\na=rtpmap:0 PCMU/8000\r\n'), null);
      expect(opusFmtp(null), isNull);
    });

    test('congestion feedback is read from the audio section only', () {
      expect(audioHasTransportCc(_sdp), isTrue);
      const videoOnly =
          'm=audio 9 UDP/TLS/RTP/SAVPF 111\r\n'
          'a=rtpmap:111 opus/48000/2\r\n'
          'm=video 9 UDP/TLS/RTP/SAVPF 96\r\n'
          'a=rtcp-fb:96 transport-cc\r\n';
      expect(audioHasTransportCc(videoOnly), isFalse);
      expect(audioHasTransportCc(null), isFalse);
    });

    test('the codec in use comes from the outgoing audio stream', () {
      expect(
        audioCodecInUse(_stats(audioBytes: 1)),
        'audio/opus minptime=10;useinbandfec=1',
      );
      expect(audioCodecInUse(const []), isNull);
    });
  });
}
