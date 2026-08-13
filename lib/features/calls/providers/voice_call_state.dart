import 'package:flutter_webrtc/flutter_webrtc.dart';

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
    this.screenSharing = false,
    this.remoteScreenStream,
    this.screenShareError,
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
  final bool screenSharing;
  final MediaStream? remoteScreenStream;
  final String? screenShareError;
  final String? pendingConversationId;
  final String? pendingPeerName;
  final String? pendingPeerAvatar;
  final DateTime? connectedAt;
  final String? error;

  bool get active =>
      phase != VoiceCallPhase.idle &&
      phase != VoiceCallPhase.ended &&
      phase != VoiceCallPhase.failed;

  /// Phases that warrant the in-app call screen.
  /// Navigation itself is gated to Flutter foreground in [CallStoreSync]
  /// so background CallKit ringing is not overridden.
  bool get shouldOpenCallScreen =>
      phase == VoiceCallPhase.starting ||
      phase == VoiceCallPhase.outgoingRinging ||
      phase == VoiceCallPhase.incomingRinging ||
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
    bool? screenSharing,
    MediaStream? remoteScreenStream,
    bool clearRemoteScreen = false,
    String? screenShareError,
    bool clearScreenShareError = false,
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
    screenSharing: screenSharing ?? this.screenSharing,
    remoteScreenStream: clearRemoteScreen
        ? null
        : (remoteScreenStream ?? this.remoteScreenStream),
    screenShareError: clearScreenShareError
        ? null
        : (screenShareError ?? this.screenShareError),
    pendingConversationId: pendingConversationId ?? this.pendingConversationId,
    pendingPeerName: pendingPeerName ?? this.pendingPeerName,
    pendingPeerAvatar: pendingPeerAvatar ?? this.pendingPeerAvatar,
    connectedAt: clearConnectedAt ? null : (connectedAt ?? this.connectedAt),
    error: clearError ? null : (error ?? this.error),
  );
}
