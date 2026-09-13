import 'package:livekit_client/livekit_client.dart';

import '../data/models/group_call.dart';

/// `lobby` is a local phase with no server side: nothing is joined and no room
/// exists yet, so backing out of it costs the call nothing.
enum GroupCallPhase { idle, lobby, joining, connected, failed }

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

/// What the lobby knows before anybody has joined anything.
class GroupLobbyView {
  const GroupLobbyView({
    required this.conversationId,
    required this.conversationName,
    this.call,
    this.joinMuted = false,
  });

  final String conversationId;
  final String conversationName;

  /// The call already running in there, if this is a join rather than a start.
  final GroupCall? call;

  /// Carried into the room as the initial microphone state.
  final bool joinMuted;

  GroupLobbyView copyWith({
    GroupCall? call,
    bool clearCall = false,
    bool? joinMuted,
  }) => GroupLobbyView(
    conversationId: conversationId,
    conversationName: conversationName,
    call: clearCall ? null : (call ?? this.call),
    joinMuted: joinMuted ?? this.joinMuted,
  );
}

/// One floating emoji, alive for a few seconds and then dropped.
class GroupCallReaction {
  const GroupCallReaction({
    required this.id,
    required this.identity,
    required this.name,
    required this.emoji,
    required this.at,
  });

  final String id;
  final String identity;
  final String name;
  final String emoji;
  final DateTime at;
}

class GroupCallState {
  const GroupCallState({
    this.phase = GroupCallPhase.idle,
    this.call,
    this.lobby,
    this.participants = const [],
    this.screen,
    this.muted = false,
    this.reconnecting = false,
    this.speaker = true,
    this.microphoneUnavailable = false,
    this.sharingScreen = false,
    this.screenSharePending = false,
    this.hands = const {},
    this.reactions = const [],
    this.activeCalls = const {},
    this.invite,
    this.error,
  });

  final GroupCallPhase phase;
  final GroupCall? call;
  final GroupLobbyView? lobby;
  final List<GroupParticipantView> participants;
  final GroupScreenView? screen;
  final bool muted;
  final bool reconnecting;
  final bool speaker;
  final bool microphoneUnavailable;
  final bool sharingScreen;
  final bool screenSharePending;

  /// Identity -> the moment that hand went up, so the queue can be ordered.
  final Map<String, DateTime> hands;
  final List<GroupCallReaction> reactions;

  /// Live call per conversation id — drives the channel header button.
  final Map<String, GroupCall> activeCalls;

  /// Group call ringing on this device right now, if any.
  final GroupCall? invite;
  final String? error;

  bool get active =>
      phase == GroupCallPhase.joining || phase == GroupCallPhase.connected;

  String get title => call?.title ?? lobby?.conversationName ?? 'Group call';

  GroupCall? callFor(String conversationId) => activeCalls[conversationId];

  /// Newest reaction per person, so a tile can show what its owner just sent.
  Map<String, String> get reactionByIdentity => {
    for (final reaction in reactions) reaction.identity: reaction.emoji,
  };

  GroupCallState copyWith({
    GroupCallPhase? phase,
    GroupCall? call,
    bool clearCall = false,
    GroupLobbyView? lobby,
    bool clearLobby = false,
    List<GroupParticipantView>? participants,
    GroupScreenView? screen,
    bool clearScreen = false,
    bool? muted,
    bool? reconnecting,
    bool? speaker,
    bool? microphoneUnavailable,
    bool? sharingScreen,
    bool? screenSharePending,
    Map<String, DateTime>? hands,
    List<GroupCallReaction>? reactions,
    Map<String, GroupCall>? activeCalls,
    GroupCall? invite,
    bool clearInvite = false,
    String? error,
    bool clearError = false,
  }) => GroupCallState(
    phase: phase ?? this.phase,
    call: clearCall ? null : (call ?? this.call),
    lobby: clearLobby ? null : (lobby ?? this.lobby),
    participants: participants ?? this.participants,
    screen: clearScreen ? null : (screen ?? this.screen),
    muted: muted ?? this.muted,
    reconnecting: reconnecting ?? this.reconnecting,
    speaker: speaker ?? this.speaker,
    microphoneUnavailable: microphoneUnavailable ?? this.microphoneUnavailable,
    sharingScreen: sharingScreen ?? this.sharingScreen,
    screenSharePending: screenSharePending ?? this.screenSharePending,
    hands: hands ?? this.hands,
    reactions: reactions ?? this.reactions,
    activeCalls: activeCalls ?? this.activeCalls,
    invite: clearInvite ? null : (invite ?? this.invite),
    error: clearError ? null : (error ?? this.error),
  );
}

/// Identity of the tile the speaker view should promote, sticky when silent.
String? activeSpeakerIdentity(
  List<GroupParticipantView> participants,
  String? previous,
) {
  if (participants.isEmpty) return null;
  for (final participant in participants) {
    if (participant.isSpeaking && !participant.isMuted) {
      return participant.identity;
    }
  }
  if (previous != null &&
      participants.any((participant) => participant.identity == previous)) {
    return previous;
  }
  for (final participant in participants) {
    if (!participant.isLocal) return participant.identity;
  }
  return participants.first.identity;
}
