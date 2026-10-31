import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Lets a caller repeat an offer until it hears back, which is the only cure
/// for a lost one: the server relays to whichever sockets are open and keeps
/// nothing, so neither side can tell an offer went missing.
///
/// Repeats have to be harmless, and one can land after the first was answered
/// (the answer simply had not arrived yet). So a repeat gets the answer already
/// given, which also recovers an answer that was the one lost.
///
/// An offer is recognised by its `o=` session line and ICE credentials, never
/// its text: measured on a phone, gathering rewrites the `m=` port and the `c=`
/// address as well as adding candidates. A renegotiation moves the session
/// version and an ICE restart the credentials, so neither reads as a repeat.
class VoiceOfferReplay {
  String? _offerKey;
  String? _answer;

  /// The answer to give if [offerSdp] repeats the offer last answered.
  String? answerFor(String offerSdp) {
    final key = _key(offerSdp);
    return key != null && key == _offerKey ? _answer : null;
  }

  void remember(String offerSdp, String answerSdp) {
    _offerKey = _key(offerSdp);
    _answer = answerSdp;
  }

  static String? _key(String sdp) {
    final lines = sdp.split(RegExp(r'\r?\n'));
    final session = lines.where((line) => line.startsWith('o=')).firstOrNull;
    if (session == null) return null;
    final ufrag = lines.where((line) => line.startsWith('a=ice-ufrag:'));
    return '$session|${ufrag.join('|')}';
  }
}

/// An answer means something only while an offer of ours is waiting for one.
/// Applied in any other state WebRTC throws, and before a call has connected
/// that throw ends it. A state that could not be read is left to WebRTC.
bool answerApplies(RTCSignalingState? state) =>
    state == null || state == RTCSignalingState.RTCSignalingStateHaveLocalOffer;
