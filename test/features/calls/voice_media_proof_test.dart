import 'package:ababilx/features/calls/webrtc/voice_media_proof.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

List<StatsReport> _stats({
  Map<String, num> inbound = const {},
  num? sent,
  num? reports,
}) => [
  for (final e in inbound.entries)
    StatsReport(e.key, 'inbound-rtp', 0, {
      'kind': 'audio',
      'packetsReceived': e.value,
    }),
  StatsReport('video-in', 'inbound-rtp', 0, {
    'kind': 'video',
    'packetsReceived': DateTime.now().microsecondsSinceEpoch,
  }),
  if (sent != null)
    StatsReport('out', 'outbound-rtp', 0, {
      'kind': 'audio',
      'packetsSent': sent,
    }),
  if (reports != null)
    StatsReport('ri', 'remote-inbound-rtp', 0, {
      'kind': 'audio',
      'roundTripTimeMeasurements': reports,
    }),
];

void main() {
  group('with nothing going out', () {
    test('incoming audio is all there is to go on', () {
      final proof = VoiceMediaProof();
      expect(proof.update(_stats(inbound: {'a': 100})), isFalse);
      expect(proof.update(_stats(inbound: {'a': 100})), isFalse);
      expect(proof.update(_stats(inbound: {'a': 110})), isTrue);
      expect(proof.update(_stats(inbound: {'a': 110})), isFalse);
    });

    test('new SSRCs and reset counters need fresh packets', () {
      final proof = VoiceMediaProof();
      expect(proof.update(_stats(inbound: {'old': 100})), isFalse);
      expect(proof.update(_stats(inbound: {'new': 200})), isFalse);
      expect(proof.update(_stats(inbound: {'new': 201})), isTrue);
      expect(proof.update(_stats(inbound: {'new': 0})), isFalse);
      expect(proof.update(_stats(inbound: {'new': 1})), isTrue);
    });

    test('a failed read starts the comparison over', () {
      final proof = VoiceMediaProof();
      proof.update(_stats(inbound: {'a': 100}));
      proof.reset();
      expect(proof.update(_stats(inbound: {'a': 500})), isFalse);
    });
  });

  group('while we are sending', () {
    test('incoming audio alone proves nothing: they may not hear us', () {
      final proof = VoiceMediaProof();
      proof.update(_stats(inbound: {'a': 100}, sent: 100, reports: 5));
      expect(
        proof.update(_stats(inbound: {'a': 200}, sent: 200, reports: 5)),
        isFalse,
      );
    });

    test('a new report from the peer proves both directions', () {
      final proof = VoiceMediaProof();
      proof.update(_stats(inbound: {'a': 100}, sent: 100, reports: 5));
      expect(
        proof.update(_stats(inbound: {'a': 200}, sent: 200, reports: 6)),
        isTrue,
      );
    });

    test('a muted peer still reports, so recovery can end', () {
      final proof = VoiceMediaProof();
      proof.update(_stats(inbound: {'a': 100}, sent: 100, reports: 5));
      expect(
        proof.update(_stats(inbound: {'a': 100}, sent: 200, reports: 6)),
        isTrue,
      );
    });

    test('a platform with no report counter falls back to incoming audio', () {
      final proof = VoiceMediaProof();
      proof.update(_stats(inbound: {'a': 100}, sent: 100));
      expect(proof.update(_stats(inbound: {'a': 200}, sent: 200)), isTrue);
    });

    test('nothing moving is no proof', () {
      final proof = VoiceMediaProof();
      proof.update(_stats(inbound: {'a': 100}, sent: 100, reports: 5));
      expect(
        proof.update(_stats(inbound: {'a': 100}, sent: 100, reports: 5)),
        isFalse,
      );
    });
  });

  test('path up needs both the connection and ICE', () {
    const c = RTCPeerConnectionState.RTCPeerConnectionStateConnected;
    const d = RTCPeerConnectionState.RTCPeerConnectionStateDisconnected;
    const iceOk = RTCIceConnectionState.RTCIceConnectionStateConnected;
    const iceDone = RTCIceConnectionState.RTCIceConnectionStateCompleted;
    const iceBad = RTCIceConnectionState.RTCIceConnectionStateDisconnected;
    expect(mediaPathUp(c, iceOk), isTrue);
    expect(mediaPathUp(c, iceDone), isTrue);
    expect(mediaPathUp(d, iceOk), isFalse);
    expect(mediaPathUp(c, iceBad), isFalse);
    expect(mediaPathUp(null, iceOk), isFalse);
    expect(mediaPathUp(c, null), isFalse);
  });
}
