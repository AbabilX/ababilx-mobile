import 'package:livekit_client/livekit_client.dart';

import '../data/models/group_call.dart';

enum GroupCallPhase { idle, joining, connected, failed }

/// One tile in the participant grid.
class GroupParticipantView {
  const GroupParticipantView({
    required this.identity,
    required this.name,
    this.avatarUrl,
    required this.isLocal,
    required this.isSpeaking,
    required this.isMuted,
  });

  final String identity;
  final String name;
  final String? avatarUrl;
  final bool isLocal;
  final bool isSpeaking;
  final bool isMuted;
}

/// The single screen share currently on stage, if any.
class GroupScreenView {
  const GroupScreenView({
    required this.participantName,
    required this.isLocal,
    required this.track,
  });

  final String participantName;
  final bool isLocal;
  final VideoTrack track;
}

class GroupCallState {
  const GroupCallState({
    this.phase = GroupCallPhase.idle,
    this.call,
    this.participants = const [],
    this.screen,
    this.muted = false,
    this.speaker = true,
    this.microphoneUnavailable = false,
    this.sharingScreen = false,
    this.screenSharePending = false,
    this.activeCalls = const {},
    this.invite,
    this.error,
  });

  final GroupCallPhase phase;
  final GroupCall? call;
  final List<GroupParticipantView> participants;
  final GroupScreenView? screen;
  final bool muted;
  final bool speaker;
  final bool microphoneUnavailable;
  final bool sharingScreen;
  final bool screenSharePending;

  /// Live call per conversation id — drives the channel header button.
  final Map<String, GroupCall> activeCalls;

  /// Group call ringing on this device right now, if any.
  final GroupCall? invite;
  final String? error;

  bool get active =>
      phase == GroupCallPhase.joining || phase == GroupCallPhase.connected;

  String get title => call?.title ?? 'Group call';

  GroupCall? callFor(String conversationId) => activeCalls[conversationId];

  GroupCallState copyWith({
    GroupCallPhase? phase,
    GroupCall? call,
    bool clearCall = false,
    List<GroupParticipantView>? participants,
    GroupScreenView? screen,
    bool clearScreen = false,
    bool? muted,
    bool? speaker,
    bool? microphoneUnavailable,
    bool? sharingScreen,
    bool? screenSharePending,
    Map<String, GroupCall>? activeCalls,
    GroupCall? invite,
    bool clearInvite = false,
    String? error,
    bool clearError = false,
  }) => GroupCallState(
    phase: phase ?? this.phase,
    call: clearCall ? null : (call ?? this.call),
    participants: participants ?? this.participants,
    screen: clearScreen ? null : (screen ?? this.screen),
    muted: muted ?? this.muted,
    speaker: speaker ?? this.speaker,
    microphoneUnavailable: microphoneUnavailable ?? this.microphoneUnavailable,
    sharingScreen: sharingScreen ?? this.sharingScreen,
    screenSharePending: screenSharePending ?? this.screenSharePending,
    activeCalls: activeCalls ?? this.activeCalls,
    invite: clearInvite ? null : (invite ?? this.invite),
    error: clearError ? null : (error ?? this.error),
  );
}
