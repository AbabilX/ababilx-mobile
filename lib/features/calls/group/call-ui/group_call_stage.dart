import 'package:flutter/material.dart';

import '../providers/group_call_state.dart';
import '../widgets/group_screen_stage.dart';
import 'call_stage_view.dart';
import 'call_surface.dart';
import 'participant_tile.dart';

/// Picks the layout: a shared screen always wins the stage, then speaker view,
/// then the equal grid.
class GroupCallStage extends StatefulWidget {
  const GroupCallStage({super.key, required this.state, required this.view});

  final GroupCallState state;
  final CallStageView view;

  @override
  State<GroupCallStage> createState() => _GroupCallStageState();
}

class _GroupCallStageState extends State<GroupCallStage> {
  /// Sticky, so a pause between sentences does not shuffle the big tile away.
  String? _lastSpeaker;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final participants = state.participants;
    if (participants.isEmpty) {
      return Center(
        child: Text(
          'Waiting for others to join…',
          style: TextStyle(color: CallColors.of(context).faint),
        ),
      );
    }
    final emoji = state.reactionByIdentity;
    final screen = state.screen;

    if (screen != null) {
      return Column(
        children: [
          Expanded(child: GroupScreenStage(screen: screen)),
          const SizedBox(height: 10),
          _Strip(participants: participants, hands: state.hands, emoji: emoji),
        ],
      );
    }

    if (widget.view == CallStageView.speaker && participants.length > 1) {
      _lastSpeaker = activeSpeakerIdentity(participants, _lastSpeaker);
      final speaker = participants.firstWhere(
        (participant) => participant.identity == _lastSpeaker,
        orElse: () => participants.first,
      );
      final others = participants
          .where((participant) => participant.identity != speaker.identity)
          .toList();
      return Column(
        children: [
          Expanded(
            child: ParticipantTile(
              participant: speaker,
              size: CallTileSize.large,
              handRaised: state.hands.containsKey(speaker.identity),
              reaction: emoji[speaker.identity],
            ),
          ),
          const SizedBox(height: 10),
          _Strip(participants: others, hands: state.hands, emoji: emoji),
        ],
      );
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: callGridColumns(participants.length),
        childAspectRatio: participants.length <= 1 ? 0.9 : 1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: participants.length,
      itemBuilder: (_, index) {
        final participant = participants[index];
        return ParticipantTile(
          participant: participant,
          handRaised: state.hands.containsKey(participant.identity),
          reaction: emoji[participant.identity],
        );
      },
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({
    required this.participants,
    required this.hands,
    required this.emoji,
  });

  final List<GroupParticipantView> participants;
  final Map<String, DateTime> hands;
  final Map<String, String> emoji;

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: participants.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final participant = participants[index];
          return SizedBox(
            width: 96,
            child: ParticipantTile(
              participant: participant,
              size: CallTileSize.small,
              handRaised: hands.containsKey(participant.identity),
              reaction: emoji[participant.identity],
            ),
          );
        },
      ),
    );
  }
}
