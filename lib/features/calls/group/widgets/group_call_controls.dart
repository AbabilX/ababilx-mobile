import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/group_call_provider.dart';
import 'group_call_leave_dialog.dart';

/// Mute · speaker · screen share · leave — mirrors web `group-call-controls.tsx`.
class GroupCallControls extends ConsumerWidget {
  const GroupCallControls({super.key, required this.state});

  final GroupCallState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(groupCallProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    final connected = state.phase == GroupCallPhase.connected;
    final otherSharing =
        state.call?.screenSharerId != null && !state.sharingScreen;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state.microphoneUnavailable)
          _Hint('Listening only — no microphone was detected.', colors.tertiary),
        if (otherSharing)
          _Hint(
            '${state.call?.screenSharerName ?? "Another participant"} is '
            'sharing — you can take over',
            colors.onSurfaceVariant,
          ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (connected) ...[
              _CircleButton(
                icon: state.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                tooltip: state.microphoneUnavailable
                    ? 'Microphone unavailable'
                    : state.muted
                    ? 'Unmute'
                    : 'Mute',
                enabled: !state.microphoneUnavailable,
                onTap: notifier.toggleMute,
              ),
              const SizedBox(width: 14),
              _CircleButton(
                icon: state.speaker
                    ? Icons.volume_up_rounded
                    : Icons.hearing_rounded,
                tooltip: state.speaker ? 'Speaker on' : 'Earpiece',
                onTap: notifier.toggleSpeaker,
              ),
              const SizedBox(width: 14),
              _CircleButton(
                icon: state.sharingScreen
                    ? Icons.stop_screen_share_rounded
                    : Icons.screen_share_rounded,
                tooltip: state.sharingScreen
                    ? 'Stop sharing'
                    : otherSharing
                    ? 'Take over screen'
                    : 'Share screen',
                highlighted: state.sharingScreen,
                busy: state.screenSharePending,
                enabled: !state.screenSharePending,
                onTap: notifier.toggleScreenShare,
              ),
              const SizedBox(width: 14),
            ],
            _CircleButton(
              icon: Icons.call_end_rounded,
              tooltip: 'Leave call',
              background: colors.error,
              foreground: colors.onError,
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
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
    ),
  );
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.enabled = true,
    this.busy = false,
    this.highlighted = false,
    this.background,
    this.foreground,
  });

  final IconData icon;
  final String tooltip;
  final Future<void> Function() onTap;
  final bool enabled;
  final bool busy;
  final bool highlighted;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bg =
        background ??
        (highlighted ? colors.primary : colors.surfaceContainerHighest);
    final fg =
        foreground ?? (highlighted ? colors.onPrimary : colors.onSurface);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: enabled ? bg : bg.withValues(alpha: 0.4),
        shape: const CircleBorder(),
        child: InkShape(
          enabled: enabled && !busy,
          onTap: onTap,
          child: SizedBox(
            width: 56,
            height: 56,
            child: busy
                ? Padding(
                    padding: const EdgeInsets.all(18),
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                : Icon(icon, color: fg),
          ),
        ),
      ),
    );
  }
}

/// Circular ink response that keeps the ripple inside the button shape.
class InkShape extends StatelessWidget {
  const InkShape({
    super.key,
    required this.child,
    required this.onTap,
    this.enabled = true,
  });

  final Widget child;
  final Future<void> Function() onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) => InkWell(
    customBorder: const CircleBorder(),
    onTap: enabled ? () => onTap() : null,
    child: child,
  );
}
