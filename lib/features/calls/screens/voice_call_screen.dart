import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/root_back.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../providers/voice_call_provider.dart';

class VoiceCallScreen extends ConsumerStatefulWidget {
  const VoiceCallScreen({super.key});

  @override
  ConsumerState<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends ConsumerState<VoiceCallScreen> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final call = ref.watch(voiceCallProvider);
    final notifier = ref.read(voiceCallProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.primaryContainer, colors.surface, colors.surface],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Minimize call',
                    onPressed: () => popOrGoHome(context),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ),
                const Spacer(),
                AppAvatar(
                  size: 112,
                  url: call.peerAvatar,
                  name: call.peerName,
                  border: Border.all(color: colors.outlineVariant, width: 2),
                ),
                const SizedBox(height: 24),
                Text(
                  call.peerName,
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _status(call),
                  style: textTheme.bodyLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (call.error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    call.error!,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(color: colors.error),
                  ),
                ],
                const Spacer(flex: 2),
                if (call.phase == VoiceCallPhase.incomingRinging)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _CallControl(
                        label: 'Decline',
                        icon: Icons.call_end_rounded,
                        background: colors.error,
                        foreground: colors.onError,
                        onPressed: notifier.declineIncoming,
                      ),
                      _CallControl(
                        label: 'Accept',
                        icon: Icons.call_rounded,
                        background: colors.primary,
                        foreground: colors.onPrimary,
                        onPressed: notifier.acceptIncoming,
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _CallControl(
                        label: call.muted ? 'Unmute' : 'Mute',
                        icon: call.muted
                            ? Icons.mic_off_rounded
                            : Icons.mic_rounded,
                        selected: call.muted,
                        onPressed:
                            call.active && call.phase != VoiceCallPhase.starting
                            ? notifier.toggleMute
                            : null,
                      ),
                      _CallControl(
                        label: 'End',
                        icon: Icons.call_end_rounded,
                        background: colors.error,
                        foreground: colors.onError,
                        onPressed:
                            call.active && call.phase != VoiceCallPhase.starting
                            ? notifier.hangUp
                            : null,
                      ),
                      _CallControl(
                        label: 'Speaker',
                        icon: call.speaker
                            ? Icons.volume_up_rounded
                            : Icons.hearing_rounded,
                        selected: call.speaker,
                        onPressed:
                            call.active && call.phase != VoiceCallPhase.starting
                            ? notifier.toggleSpeaker
                            : null,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _status(VoiceCallState state) {
    switch (state.phase) {
      case VoiceCallPhase.idle:
        return 'Call finished';
      case VoiceCallPhase.starting:
        return 'Starting call…';
      case VoiceCallPhase.outgoingRinging:
        // Caller is waiting; only the callee is actually ringing.
        return 'Calling…';
      case VoiceCallPhase.incomingRinging:
        return 'Incoming voice call';
      case VoiceCallPhase.connecting:
        return 'Connecting…';
      case VoiceCallPhase.connected:
        final started = state.connectedAt;
        if (started == null) return 'Connected';
        final duration = DateTime.now().difference(started);
        final minutes = duration.inMinutes.toString().padLeft(2, '0');
        final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
        return '$minutes:$seconds';
      case VoiceCallPhase.ended:
        return 'Call ended';
      case VoiceCallPhase.failed:
        return 'Call failed';
    }
  }
}

class _CallControl extends StatelessWidget {
  const _CallControl({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.selected = false,
    this.background,
    this.foreground,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool selected;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bg =
        background ??
        (selected ? colors.primary : colors.surfaceContainerHighest);
    final fg = foreground ?? (selected ? colors.onPrimary : colors.onSurface);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filled(
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            disabledBackgroundColor: bg.withValues(alpha: 0.45),
            disabledForegroundColor: fg.withValues(alpha: 0.45),
            minimumSize: const Size(62, 62),
          ),
          icon: Icon(icon, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}
