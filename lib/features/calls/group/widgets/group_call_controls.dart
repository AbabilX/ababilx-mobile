import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_translations.dart';
import '../call-ui/call_round_button.dart';
import '../call-ui/call_surface.dart';
import '../call-ui/reaction_picker.dart';
import '../call_icons.dart';
import '../providers/group_call_provider.dart';
import 'group_call_leave_dialog.dart';

/// Mute · share · hand · react · leave, on one row that never wraps.
///
/// Speaker routing and participants live in the header — not here — so the
/// bar stays five controls and does not wrap on a narrow phone.
class GroupCallControls extends ConsumerWidget {
  const GroupCallControls({super.key, required this.state});

  final GroupCallState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(groupCallProvider.notifier);
    final lang = ref.watch(appLanguageProvider);
    String tr(String key) => AppTranslations.of(lang, key);
    final palette = CallColors.of(context);
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
          _Hint(tr('group_listening_hint'), palette.hand),
        if (otherSharing)
          _Hint(
            tr('group_sharing_hint').replaceAll(
              '{name}',
              state.call?.screenSharerName ?? tr('group_someone'),
            ),
            palette.faint,
          ),
        const SizedBox(height: 8),
        CallControlBar(
          count: connected ? 5 : 1,
          builder: (diameter) => [
            if (connected) ...[
              CallRoundButton(
                diameter: diameter,
                icon: state.muted ? CallIcons.micMuted : CallIcons.micOn,
                label: state.microphoneUnavailable
                    ? tr('group_mic_unavailable')
                    : state.muted
                    ? tr('group_unmute')
                    : tr('group_mute'),
                tone: state.muted
                    ? CallButtonTone.active
                    : CallButtonTone.neutral,
                enabled: !state.microphoneUnavailable,
                onTap: notifier.toggleMute,
              ),
              CallRoundButton(
                diameter: diameter,
                icon: CallIcons.screenShare,
                label: state.sharingScreen
                    ? tr('group_stop_sharing')
                    : otherSharing
                    ? tr('group_take_over')
                    : tr('group_share_screen'),
                tone: state.sharingScreen
                    ? CallButtonTone.active
                    : CallButtonTone.neutral,
                busy: state.screenSharePending,
                enabled: !state.reconnecting,
                onTap: notifier.toggleScreenShare,
              ),
              CallRoundButton(
                diameter: diameter,
                icon: CallIcons.raiseHand,
                label: handRaised
                    ? tr('group_lower_hand')
                    : tr('group_raise_hand'),
                tone: handRaised
                    ? CallButtonTone.active
                    : CallButtonTone.neutral,
                enabled: !state.reconnecting,
                onTap: notifier.toggleHand,
              ),
              CallRoundButton(
                diameter: diameter,
                icon: CallIcons.reaction,
                label: tr('group_reaction'),
                enabled: !state.reconnecting,
                onTap: () => showReactionPicker(context, notifier.sendReaction),
              ),
            ],
            CallRoundButton(
              diameter: diameter,
              icon: CallIcons.leave,
              label: tr('group_leave'),
              tone: CallButtonTone.danger,
              onTap: () async {
                if (!await confirmLeaveGroupCall(context, lang: lang)) return;
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
