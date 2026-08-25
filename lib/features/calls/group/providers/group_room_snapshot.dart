import 'dart:convert';

import 'package:livekit_client/livekit_client.dart';

import 'group_call_state.dart';

/// Flattened read of a connected [Room] — mirrors web `group-room-snapshot.ts`.
class GroupMediaSnapshot {
  const GroupMediaSnapshot({
    required this.participants,
    required this.screen,
    required this.muted,
    required this.sharingScreen,
  });

  final List<GroupParticipantView> participants;
  final GroupScreenView? screen;
  final bool muted;
  final bool sharingScreen;
}

/// [screenOwnerId] is the server's authoritative sharer, so a stale track that
/// has not finished unpublishing cannot win the stage from the current owner.
GroupMediaSnapshot groupRoomSnapshot(Room room, {String? screenOwnerId}) {
  final local = room.localParticipant;
  final members = <Participant>[?local, ...room.remoteParticipants.values];

  GroupScreenView? screen;
  final participants = <GroupParticipantView>[];

  for (final participant in members) {
    final microphone = participant.getTrackPublicationBySource(
      TrackSource.microphone,
    );
    final screenTrack = _screenTrack(participant);
    final preferred =
        screenOwnerId == null || participant.identity == screenOwnerId;
    if (screen == null && preferred && screenTrack != null) {
      screen = GroupScreenView(
        participantName: _displayName(participant),
        isLocal: identical(participant, local),
        track: screenTrack,
      );
    }
    participants.add(
      GroupParticipantView(
        identity: participant.identity,
        name: _displayName(participant),
        avatarUrl: participantAvatarUrl(participant.metadata),
        isLocal: identical(participant, local),
        isSpeaking: participant.isSpeaking,
        isMuted: microphone == null || microphone.muted,
      ),
    );
  }

  final localMicrophone = local?.getTrackPublicationBySource(
    TrackSource.microphone,
  );
  return GroupMediaSnapshot(
    participants: participants,
    screen: screen,
    muted: localMicrophone == null || localMicrophone.muted,
    sharingScreen: local != null && _screenTrack(local) != null,
  );
}

VideoTrack? _screenTrack(Participant participant) {
  final publication = participant.getTrackPublicationBySource(
    TrackSource.screenShareVideo,
  );
  final track = publication?.track;
  return track is VideoTrack ? track : null;
}

String _displayName(Participant participant) =>
    participant.name.trim().isNotEmpty
    ? participant.name
    : participant.identity;

/// The server packs `{"avatar_url": …}` into the participant token metadata.
String? participantAvatarUrl(String? metadata) {
  if (metadata == null || metadata.isEmpty) return null;
  try {
    final parsed = jsonDecode(metadata);
    if (parsed is! Map) return null;
    final url = parsed['avatar_url'];
    return url is String && url.trim().isNotEmpty ? url : null;
  } catch (_) {
    return null;
  }
}
