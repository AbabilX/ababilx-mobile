import 'package:ababilx/features/calls/webrtc/voice_offer_replay.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

const _offer =
    'v=0\r\n'
    'o=- 111 2 IN IP4 127.0.0.1\r\n'
    'm=audio 9 UDP/TLS/RTP/SAVPF 111\r\n'
    'c=IN IP4 0.0.0.0\r\n'
    'a=rtcp:9 IN IP4 0.0.0.0\r\n'
    'a=ice-ufrag:abcd\r\n'
    'a=ice-pwd:secret\r\n'
    'a=rtpmap:111 opus/48000/2\r\n';

/// The same description later, as a phone really wrote it: gathering added
/// candidates and moved the port and address to the default candidate's.
const _sameLater =
    'v=0\r\n'
    'o=- 111 2 IN IP4 127.0.0.1\r\n'
    'm=audio 5000 UDP/TLS/RTP/SAVPF 111\r\n'
    'c=IN IP4 192.0.2.1\r\n'
    'a=rtcp:9 IN IP4 0.0.0.0\r\n'
    'a=candidate:1 1 udp 1 192.0.2.1 5000 typ host\r\n'
    'a=ice-ufrag:abcd\r\n'
    'a=ice-pwd:secret\r\n'
    'a=rtpmap:111 opus/48000/2\r\n'
    'a=end-of-candidates\r\n';

void main() {
  group('a repeated offer', () {
    test('nothing answered yet: nothing to replay', () {
      expect(VoiceOfferReplay().answerFor(_offer), isNull);
    });

    test('gets the answer already given, even with candidates added', () {
      final replay = VoiceOfferReplay()..remember(_offer, 'answer-1');
      expect(replay.answerFor(_offer), 'answer-1');
      expect(replay.answerFor(_sameLater), 'answer-1');
    });

    test('and the other way round: first seen with candidates', () {
      final replay = VoiceOfferReplay()..remember(_sameLater, 'answer-1');
      expect(replay.answerFor(_offer), 'answer-1');
    });

    test('an ICE restart is a new offer, never a repeat', () {
      final replay = VoiceOfferReplay()..remember(_offer, 'answer-1');
      final restart = _offer.replaceAll('abcd', 'wxyz');
      expect(replay.answerFor(restart), isNull);
    });

    test('a renegotiation is a new offer: the session version moved', () {
      final replay = VoiceOfferReplay()..remember(_offer, 'answer-1');
      final next = _offer.replaceAll('o=- 111 2', 'o=- 111 3');
      expect(replay.answerFor(next), isNull);
    });

    test('an offer with no session line is never taken for a repeat', () {
      final replay = VoiceOfferReplay()..remember('m=audio 9', 'answer-1');
      expect(replay.answerFor('m=audio 9'), isNull);
    });

    test('only the newest answer is kept', () {
      final restart = _offer.replaceAll('abcd', 'wxyz');
      final replay = VoiceOfferReplay()
        ..remember(_offer, 'answer-1')
        ..remember(restart, 'answer-2');
      expect(replay.answerFor(restart), 'answer-2');
      expect(replay.answerFor(_offer), isNull);
    });
  });

  group('an answer', () {
    test('applies only to an offer of ours still waiting', () {
      expect(
        answerApplies(RTCSignalingState.RTCSignalingStateHaveLocalOffer),
        isTrue,
      );
      expect(answerApplies(RTCSignalingState.RTCSignalingStateStable), isFalse);
      expect(answerApplies(RTCSignalingState.RTCSignalingStateClosed), isFalse);
    });

    test('an unknown state is left to WebRTC to judge', () {
      expect(answerApplies(null), isTrue);
    });
  });
}
