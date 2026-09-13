import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/group_call_provider.dart';

import '../../../../shared/widgets/app_avatar.dart';
import '../call_icons.dart';
import '../signals/call_signals.dart';
import 'call_surface.dart';

/// The roster. Hands come first and in the order they went up — that ordering
/// is the only thing turning raised hands into an actual queue.
Future<void> showParticipantsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: CallColors.of(context).panel,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => Consumer(
        builder: (_, ref, _) => SafeArea(
          child: ParticipantsSheet(state: ref.watch(groupCallProvider)),
        ),
      ),
    );

class ParticipantsSheet extends StatelessWidget {
  const ParticipantsSheet({super.key, required this.state});

  final GroupCallState state;

  List<GroupParticipantView> get _ordered {
    final queue = handQueue(state.hands);
    int rank(GroupParticipantView participant) {
      final index = queue.indexOf(participant.identity);
      if (index != -1) return index;
      return queue.length + (participant.isLocal ? 0 : 1);
    }

    return [...state.participants]..sort((a, b) => rank(a).compareTo(rank(b)));
  }

  @override
  Widget build(BuildContext context) {
    final palette = CallColors.of(context);
    final ordered = _ordered;
    final sharerId = state.call?.screenSharerId;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              Text(
                'In this call · ${ordered.length}',
                style: TextStyle(
                  color: palette.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: ordered.length,
            itemBuilder: (_, index) => _Row(
              participant: ordered[index],
              queuePosition: state.hands.containsKey(ordered[index].identity)
                  ? index + 1
                  : null,
              sharing: ordered[index].identity == sharerId,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.participant,
    required this.queuePosition,
    required this.sharing,
  });

  final GroupParticipantView participant;
  final int? queuePosition;
  final bool sharing;

  @override
  Widget build(BuildContext context) {
    final palette = CallColors.of(context);
    final subtitle = sharing
        ? 'Sharing screen'
        : queuePosition != null
        ? 'Hand raised · #$queuePosition'
        : null;

    return ListTile(
      leading: AppAvatar(
        size: 38,
        url: participant.avatarUrl,
        name: participant.name,
      ),
      title: Text(
        participant.isLocal ? '${participant.name} (You)' : participant.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: palette.onSurface, fontSize: 14),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: TextStyle(
                color: sharing ? palette.accent : palette.hand,
                fontSize: 12,
              ),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (queuePosition != null)
            CallIcon(CallIcons.raiseHand, size: 18, color: palette.hand),
          const SizedBox(width: 10),
          CallIcon(
            participant.isMuted ? CallIcons.micMuted : CallIcons.micOn,
            size: 18,
            color: participant.isMuted
                ? palette.muted
                : participant.isSpeaking
                ? palette.accent
                : palette.faint,
          ),
        ],
      ),
    );
  }
}
