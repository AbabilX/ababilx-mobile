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
    this.reconnectingSince,
    this.remoteScreenStream,
    this.screenShareError,
    this.localCameraStream,
    this.cameraFront = true,
    this.remoteCameraStream,
    this.cameraError,
    this.pendingConversationId,
    this.pendingPeerName,
    this.pendingPeerAvatar,
    this.pendingVideo = false,
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

  /// When the current recovery began, or null when media is flowing. The call
  /// stays [VoiceCallPhase.connected] throughout on purpose — the ongoing-call
  /// notification, the audio route and the call screen must all survive a
  /// recovery, and only the status line changes. Stored as an instant rather
  /// than a flag so the status line can soften its wording as it drags on.
  final DateTime? reconnectingSince;

  bool get reconnecting => reconnectingSince != null;
  final MediaStream? remoteScreenStream;
  final String? screenShareError;

  /// Our own camera while it is on. Mirrored in the preview when [cameraFront].
  final MediaStream? localCameraStream;
  final bool cameraFront;

  /// The peer's camera while theirs is on.
  final MediaStream? remoteCameraStream;
  final String? cameraError;

  bool get cameraOn => localCameraStream != null;

  /// Placed as a video call — what the ring screen says and whether the
  /// camera opens with the call. Either side may turn it off afterwards.
  bool get isVideoCall => call?.isVideo ?? pendingVideo;
  final String? pendingConversationId;
  final String? pendingPeerName;
  final String? pendingPeerAvatar;
  final bool pendingVideo;
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
    DateTime? reconnectingSince,
    bool clearReconnectingSince = false,
    MediaStream? remoteScreenStream,
    bool clearRemoteScreen = false,
    String? screenShareError,
    bool clearScreenShareError = false,
    MediaStream? localCameraStream,
    bool clearLocalCamera = false,
    bool? cameraFront,
    MediaStream? remoteCameraStream,
    bool clearRemoteCamera = false,
    String? cameraError,
    bool clearCameraError = false,
    String? pendingConversationId,
    String? pendingPeerName,
    String? pendingPeerAvatar,
    bool? pendingVideo,
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
    reconnectingSince: clearReconnectingSince
        ? null
        : (reconnectingSince ?? this.reconnectingSince),
    remoteScreenStream: clearRemoteScreen
        ? null
        : (remoteScreenStream ?? this.remoteScreenStream),
    screenShareError: clearScreenShareError
        ? null
        : (screenShareError ?? this.screenShareError),
    localCameraStream: clearLocalCamera
        ? null
        : (localCameraStream ?? this.localCameraStream),
    cameraFront: cameraFront ?? this.cameraFront,
    remoteCameraStream: clearRemoteCamera
        ? null
        : (remoteCameraStream ?? this.remoteCameraStream),
    cameraError: clearCameraError ? null : (cameraError ?? this.cameraError),
    pendingVideo: pendingVideo ?? this.pendingVideo,
    pendingConversationId: pendingConversationId ?? this.pendingConversationId,
    pendingPeerName: pendingPeerName ?? this.pendingPeerName,
    pendingPeerAvatar: pendingPeerAvatar ?? this.pendingPeerAvatar,
    connectedAt: clearConnectedAt ? null : (connectedAt ?? this.connectedAt),
    error: clearError ? null : (error ?? this.error),
  );
}
