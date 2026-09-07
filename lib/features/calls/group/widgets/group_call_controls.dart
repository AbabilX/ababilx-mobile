import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../call-ui/call_round_button.dart';
import '../call-ui/call_surface.dart';
import '../call-ui/participants_sheet.dart';
import '../call-ui/reaction_picker.dart';
import '../call_icons.dart';
import '../providers/group_call_provider.dart';
import 'group_call_leave_dialog.dart';

/// Mute · speaker · share · hand · react · participants · leave. Everything
/// that is "on" inverts to a white pill, so state reads without a label.
class GroupCallControls extends ConsumerWidget {
  const GroupCallControls({super.key, required this.state});

  final GroupCallState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(groupCallProvider.notifier);
    final connected = state.phase == GroupCallPhase.connected;
    final otherSharing =
        state.call?.screenSharerId != null && !state.sharingScreen;
    final localIdentity = state.participants
        .where((participant) => participant.isLocal)
        .map((participant) => participant.identity)
        .firstOrNull;
    final handRaised =
        localIdentity != null && state.hands.containsKey(localIdentity);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state.microphoneUnavailable)
          const _Hint(
            'Listening only — no microphone was detected.',
            CallSurface.hand,
          ),
        if (otherSharing)
          _Hint(
            '${state.call?.screenSharerName ?? "Someone"} is sharing — '
            'you can take over',
            CallSurface.faint,
          ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            if (connected) ...[
              CallRoundButton(
                icon: state.muted ? CallIcons.micMuted : CallIcons.micOn,
                label: state.microphoneUnavailable
                    ? 'Microphone unavailable'
                    : state.muted
                    ? 'Unmute'
                    : 'Mute',
                tone: state.muted
                    ? CallButtonTone.active
                    : CallButtonTone.neutral,
                enabled: !state.microphoneUnavailable,
                onTap: notifier.toggleMute,
              ),
              CallRoundButton(
                icon: state.speaker
                    ? CallIcons.speakerOn
                    : CallIcons.speakerOff,
                label: state.speaker ? 'Speaker on' : 'Earpiece',
                tone: state.speaker
                    ? CallButtonTone.active
                    : CallButtonTone.neutral,
                onTap: notifier.toggleSpeaker,
              ),
              CallRoundButton(
                icon: CallIcons.screenShare,
                label: state.sharingScreen
                    ? 'Stop sharing'
                    : otherSharing
                    ? 'Take over screen'
                    : 'Share screen',
                tone: state.sharingScreen
                    ? CallButtonTone.active
                    : CallButtonTone.neutral,
                busy: state.screenSharePending,
                onTap: notifier.toggleScreenShare,
              ),
              CallRoundButton(
                icon: CallIcons.raiseHand,
                label: handRaised ? 'Lower hand' : 'Raise hand',
                tone: handRaised
                    ? CallButtonTone.active
                    : CallButtonTone.neutral,
                onTap: notifier.toggleHand,
              ),
              CallRoundButton(
                icon: CallIcons.reaction,
                label: 'Send a reaction',
                onTap: () =>
                    showReactionPicker(context, notifier.sendReaction),
              ),
              CallRoundButton(
                icon: CallIcons.participants,
                label: 'Participants',
                onTap: () => showParticipantsSheet(context, state),
              ),
            ],
            CallRoundButton(
              icon: CallIcons.leave,
              label: 'Leave call',
              tone: CallButtonTone.danger,
              onTap: () async {
                if (!await confirmLeaveGroupCall(context)) return;
                await notifier.leave();
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(color: color, fontSize: 12),
    ),
  );
}
