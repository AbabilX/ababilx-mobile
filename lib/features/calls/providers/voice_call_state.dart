import '../data/models/ice_server.dart';
import '../data/models/voice_call.dart';

enum VoiceCallPhase {
  idle,
  starting,
  outgoingRinging,
  incomingRinging,
  connecting,
  connected,
  ended,
  failed,
}

class VoiceCallState {
  const VoiceCallState({
    this.phase = VoiceCallPhase.idle,
    this.call,
    this.iceServers = const [],
    this.currentUserId = '',
    this.muted = false,
    this.speaker = false,
    this.pendingConversationId,
    this.pendingPeerName,
    this.pendingPeerAvatar,
    this.connectedAt,
    this.error,
  });

  final VoiceCallPhase phase;
  final VoiceCall? call;
  final List<IceServer> iceServers;
  final String currentUserId;
  final bool muted;
  final bool speaker;
  final String? pendingConversationId;
  final String? pendingPeerName;
  final String? pendingPeerAvatar;
  final DateTime? connectedAt;
  final String? error;

  bool get active =>
      phase != VoiceCallPhase.idle &&
      phase != VoiceCallPhase.ended &&
      phase != VoiceCallPhase.failed;

  bool get shouldOpenCallScreen =>
      phase == VoiceCallPhase.starting ||
      phase == VoiceCallPhase.outgoingRinging ||
      phase == VoiceCallPhase.connecting ||
      phase == VoiceCallPhase.connected;

  String get peerName =>
      call?.peerName(currentUserId) ?? pendingPeerName ?? 'Voice call';

  String? get peerAvatar =>
      call?.peerAvatar(currentUserId) ?? pendingPeerAvatar;

  String? get conversationId => call?.conversationId ?? pendingConversationId;

  bool get outgoing => call?.callerId == currentUserId;

  VoiceCallState copyWith({
    VoiceCallPhase? phase,
    VoiceCall? call,
    List<IceServer>? iceServers,
    String? currentUserId,
    bool? muted,
    bool? speaker,
    String? pendingConversationId,
    String? pendingPeerName,
    String? pendingPeerAvatar,
    DateTime? connectedAt,
    bool clearConnectedAt = false,
    String? error,
    bool clearError = false,
  }) => VoiceCallState(
    phase: phase ?? this.phase,
    call: call ?? this.call,
    iceServers: iceServers ?? this.iceServers,
    currentUserId: currentUserId ?? this.currentUserId,
    muted: muted ?? this.muted,
    speaker: speaker ?? this.speaker,
    pendingConversationId: pendingConversationId ?? this.pendingConversationId,
    pendingPeerName: pendingPeerName ?? this.pendingPeerName,
    pendingPeerAvatar: pendingPeerAvatar ?? this.pendingPeerAvatar,
    connectedAt: clearConnectedAt ? null : (connectedAt ?? this.connectedAt),
    error: clearError ? null : (error ?? this.error),
  );
}
