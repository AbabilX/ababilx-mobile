/// What one reading of the voice path points at. Diagnostic only: this never
/// reaches the call's own badge, its reconnect logic or anything a user sees.
enum CallAudioHealth {
  /// Setup or reconnection: too early to say anything.
  settling,
  healthy,

  /// Packets are going missing on the way here.
  networkLoss,

  /// Packets arrive, but late.
  lateAudio,

  /// The network is clean and audio still breaks, or packets arrive and are
  /// not being played: the trouble is on this phone's side of the wire.
  pipelineInterruption,

  /// Samples are being made up and nothing says why yet, so no cause is claimed.
  concealment,

  /// Voice packets stopped and nothing else is arriving either.
  packetStall,

  /// No voice packets, while the connection still receives control traffic:
  /// the peer has muted, or its side has stopped sending. A real phone sends
  /// nothing at all while muted, and mute is not signalled to the other side,
  /// so the two cannot be told apart from here.
  inboundSilent,

  /// Connected, and no voice has come from the other side.
  noIncomingAudio,

  /// The stats themselves could not be read.
  statsUnavailable,
}

/// A separate fact about one reading; several can hold at once.
enum CallAudioSignal {
  networkLoss,
  jitterBufferHigh,
  concealing,
  playoutStalled,
  packetStall,
  peerSilent,
  missingInbound,
  statsUnavailable,
}

class CallAudioHealthReport {
  const CallAudioHealthReport({
    required this.status,
    this.signals = const {},
    this.stalledIntervals = 0,
    this.unsupported = const [],
  });

  final CallAudioHealth status;
  final Set<CallAudioSignal> signals;
  final int stalledIntervals;

  /// Figures this platform does not report, so nothing here can use them.
  final List<String> unsupported;
}

/// Provisional, for a developer reading the panel. Not validated on real
/// calls, and deliberately not fed into [CallNetworkLevel].
abstract final class CallAudioHealthLimits {
  /// libwebrtc reports no inbound stream until its first packet arrives.
  static const setupGraceMs = 6000;
  static const reconnectGraceMs = 4000;

  /// One empty interval is not a failure; at the 2 s poll this is 4 s.
  static const stallIntervals = 2;

  /// RTCP and STUN arrive every few seconds, so a silent path has quiet
  /// intervals of its own; this many in a row means it has gone too.
  static const silentPathQuietIntervals = 4;
  static const lossPercent = 3.0;
  static const jitterMs = 40.0;
  static const jitterBufferDelayMs = 200.0;
  static const concealmentPercent = 5.0;

  /// A normal interval carries about 100 packets. Below this the voice has
  /// just stopped or just started: a phone conceals the fade as a peer mutes,
  /// measured at 10% over 2 packets, which says nothing about a fault.
  static const packetsToJudgeConcealment = 20;

  /// How long concealing must last on a clean network to blame this phone.
  static const pipelineIntervals = 2;
  static const playoutShare = 0.5;
}
