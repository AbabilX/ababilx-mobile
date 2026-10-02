import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_translations.dart';
import '../../audio/call_audio_devices.dart';
import '../../audio/call_audio_output.dart';
import '../../widgets/call_audio_output_sheet.dart';
import '../call_icons.dart';
import '../group_call_status.dart';
import '../providers/group_call_state.dart';
import 'call_stage_view.dart';
import 'call_surface.dart';

/// Keep the title readable independently of the call's routing/layout actions.
class GroupCallHeader extends ConsumerWidget {
  const GroupCallHeader({
    super.key,
    required this.state,
    required this.view,
    required this.onView,
    required this.onParticipants,
    required this.onToggleSpeaker,
    required this.onMinimize,
  });

  final GroupCallState state;
  final CallStageView view;
  final ValueChanged<CallStageView> onView;
  final VoidCallback onParticipants;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onMinimize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = CallColors.of(context);
    final lang = ref.watch(appLanguageProvider);
    String tr(String key) => AppTranslations.of(lang, key);
    final face = CallAudioButtonFace.of(
      ref.watch(callAudioDevicesProvider).valueOrNull ?? CallAudioDevices.empty,
      speaker: state.speaker,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _HeaderButton(
              icon: CallIcons.minimize,
              label: tr('group_call_minimize'),
              onTap: onMinimize,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    groupCallTitle(state, lang),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: palette.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    groupCallStatus(state, lang),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: state.reconnecting
                          ? palette.danger
                          : palette.faint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 4,
            children: [
              _HeaderButton(
                icon: view == CallStageView.grid
                    ? CallIcons.speakerView
                    : CallIcons.gridView,
                label: tr(
                  view == CallStageView.grid
                      ? 'group_call_speaker_view'
                      : 'group_call_grid_view',
                ),
                onTap: () => onView(
                  view == CallStageView.grid
                      ? CallStageView.speaker
                      : CallStageView.grid,
                ),
              ),
              if (state.phase == GroupCallPhase.connected)
                _HeaderButton(
                  icon: switch (face.output) {
                    CallAudioOutput.handset => CallIcons.speakerOff,
                    CallAudioOutput.bluetooth => CallIcons.bluetoothAudio,
                    CallAudioOutput.wiredHeadset => CallIcons.wiredHeadset,
                    _ => CallIcons.speakerOn,
                  },
                  label: face.dropdown
                      ? tr('call_audio_output')
                      : tr(
                          state.speaker
                              ? 'group_call_speaker'
                              : 'group_call_earpiece',
                        ),
                  active: face.selected,
                  onTap: onToggleSpeaker,
                ),
              _HeaderButton(
                icon: CallIcons.participants,
                label: tr('group_call_participants'),
                onTap: onParticipants,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final CallGlyph icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final palette = CallColors.of(context);
    final fg = active ? palette.backdrop : palette.onSurface;
    return IconButton(
      tooltip: label,
      onPressed: onTap,
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: active ? palette.onSurface : null,
        foregroundColor: fg,
      ),
      icon: CallIcon(icon, color: fg, size: 22),
    );
  }
}
