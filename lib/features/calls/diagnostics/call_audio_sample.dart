/// The voice lanes of one WebRTC stats report, video left out.
///
/// A null figure was not measurable: the platform does not report it, or this
/// is the first reading of that stream and a step needs two. Never zero.
class CallAudioSample {
  const CallAudioSample({
    required this.hasInbound,
    required this.hasOutbound,
    this.packetsReceived,
    this.packetsLost,
    this.packetsSent,
    this.packetsReceivedDelta,
    this.transportPacketsDelta,
    this.lossPercent,
    this.remoteLossPercent,
    this.jitterMs,
    this.jitterBufferDelayMs,
    this.concealmentPercent,
    this.concealmentEventsDelta,
    this.playoutShare,
    this.audioLevel,
    this.inboundBps,
    this.outboundBps,
    this.retransmittedDelta,
    this.inboundCodec,
    this.outboundCodec,
    this.missingInboundFields = const [],
  });

  final bool hasInbound;
  final bool hasOutbound;

  /// Totals since the stream began.
  final int? packetsReceived;
  final int? packetsLost;
  final int? packetsSent;

  /// Steps since the previous report.
  final int? packetsReceivedDelta;

  /// Everything the connection received, RTCP and STUN included. Above zero
  /// while [packetsReceivedDelta] is zero, the path works and no voice is sent.
  final int? transportPacketsDelta;
  final int? concealmentEventsDelta;
  final int? retransmittedDelta;

  /// Share of this interval's incoming voice packets that never came.
  final double? lossPercent;

  /// What the far side says it lost of our voice: the upload half.
  final double? remoteLossPercent;
  final double? jitterMs;

  /// How long a sample waited in the jitter buffer, this interval.
  final double? jitterBufferDelayMs;

  /// Share of played samples that were made up. Concealed silence is left
  /// out: nobody can hear it, and a muted peer would otherwise read as damage.
  final double? concealmentPercent;

  /// Audio played per second of wall clock: about 1 while the device pulls.
  final double? playoutShare;
  final double? audioLevel;

  /// Payload only, no packet headers.
  final int? inboundBps;
  final int? outboundBps;
  final String? inboundCodec;
  final String? outboundCodec;

  /// Fields this platform left out of the inbound report.
  final List<String> missingInboundFields;
}
