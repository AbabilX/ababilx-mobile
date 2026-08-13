import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/root_back.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../incoming_call_ringtone.dart';
import '../providers/voice_call_provider.dart';
import '../widgets/remote_screen_view.dart';

class VoiceCallScreen extends ConsumerStatefulWidget {
  const VoiceCallScreen({super.key});

  @override
  ConsumerState<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends ConsumerState<VoiceCallScreen> {
  Timer? _clock;
  Timer? _autoClose;
  bool _ringtoneOn = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncRingtone(ref.read(voiceCallProvider).phase);
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _autoClose?.cancel();
    unawaited(IncomingCallRingtone.stop());
    super.dispose();
  }

  void _syncRingtone(VoiceCallPhase phase) {
    if (phase == VoiceCallPhase.incomingRinging) {
      if (_ringtoneOn) return;
      _ringtoneOn = true;
      unawaited(IncomingCallRingtone.start());
      return;
    }
    if (!_ringtoneOn) return;
    _ringtoneOn = false;
    unawaited(IncomingCallRingtone.stop());
  }

  void _scheduleAutoClose(VoiceCallPhase phase) {
    if (phase != VoiceCallPhase.ended && phase != VoiceCallPhase.failed) {
      _autoClose?.cancel();
      _autoClose = null;
      return;
    }
    if (_closing) return;
    _autoClose?.cancel();
    // Brief beat so the caller can read "busy" / "ended"; callee decline
    // already feels instant because phase flips before the API returns.
    final delay = phase == VoiceCallPhase.failed
        ? const Duration(milliseconds: 900)
        : const Duration(milliseconds: 650);
    _autoClose = Timer(delay, () {
      if (!mounted || _closing) return;
      final current = ref.read(voiceCallProvider).phase;
      if (current != VoiceCallPhase.ended &&
          current != VoiceCallPhase.failed &&
          current != VoiceCallPhase.idle) {
        return;
      }
      _closing = true;
      popOrGoHome(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(voiceCallProvider.select((s) => s.phase), (prev, next) {
      _syncRingtone(next);
      _scheduleAutoClose(next);
    });
    final call = ref.watch(voiceCallProvider);
    final notifier = ref.read(voiceCallProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final live =
        call.phase == VoiceCallPhase.connected ||
        call.phase == VoiceCallPhase.connecting ||
        call.phase == VoiceCallPhase.outgoingRinging ||
        call.phase == VoiceCallPhase.incomingRinging ||
        call.phase == VoiceCallPhase.starting;

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
                    tooltip: live ? 'Minimize call' : 'Close',
                    onPressed: () => popOrGoHome(context),
                    icon: Icon(
                      live
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.close_rounded,
                    ),
                  ),
                ),
                if (call.remoteScreenStream == null) const Spacer(),
                if (call.remoteScreenStream != null)
                  Expanded(
                    child: RemoteScreenView(stream: call.remoteScreenStream!),
                  )
                else
                  AppAvatar(
                    size: 120,
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
                const SizedBox(height: 8),
                Text(
                  'AbabilX voice call',
                  style: textTheme.labelLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _status(call),
                  textAlign: TextAlign.center,
                  style: call.phase == VoiceCallPhase.connected
                      ? (call.remoteScreenStream == null
                                ? textTheme.displaySmall
                                : textTheme.titleLarge)
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              letterSpacing: 1.2,
                            )
                      : textTheme.titleMedium?.copyWith(
                          color: call.phase == VoiceCallPhase.failed
                              ? colors.error
                              : colors.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
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
                if (call.screenSharing) ...[
                  const SizedBox(height: 12),
                  Text(
                    'You are sharing your screen',
                    style: textTheme.labelLarge?.copyWith(
                      color: colors.primary,
                    ),
                  ),
                ],
                if (call.screenShareError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    call.screenShareError!,
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(color: colors.error),
                  ),
                ],
                if (call.remoteScreenStream == null)
                  const Spacer(flex: 2)
                else
                  const SizedBox(height: 20),
                if (call.phase == VoiceCallPhase.incomingRinging)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _CallControl(
                        label: 'Decline',
                        icon: Icons.call_end_rounded,
                        background: colors.error,
                        foreground: colors.onError,
                        onPressed: () {
                          unawaited(IncomingCallRingtone.stop());
                          notifier.declineIncoming();
                        },
                      ),
                      _CallControl(
                        label: 'Accept',
                        icon: Icons.call_rounded,
                        background: colors.primary,
                        foreground: colors.onPrimary,
                        onPressed: () {
                          unawaited(IncomingCallRingtone.stop());
                          notifier.acceptIncoming();
                        },
                      ),
                    ],
                  )
                else if (call.phase == VoiceCallPhase.ended ||
                    call.phase == VoiceCallPhase.failed ||
                    call.phase == VoiceCallPhase.idle)
                  FilledButton.tonal(
                    onPressed: () => popOrGoHome(context),
                    child: const Text('Done'),
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
                        label: call.screenSharing ? 'Stop share' : 'Share',
                        icon: call.screenSharing
                            ? Icons.stop_screen_share_rounded
                            : Icons.screen_share_rounded,
                        selected: call.screenSharing,
                        onPressed:
                            call.phase == VoiceCallPhase.connected &&
                                (call.remoteScreenStream == null ||
                                    call.screenSharing)
                            ? notifier.toggleScreenShare
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
                      _CallControl(
                        label: 'End',
                        icon: Icons.call_end_rounded,
                        background: colors.error,
                        foreground: colors.onError,
                        onPressed:
                            call.active && call.phase != VoiceCallPhase.starting
                            ? () {
                                unawaited(IncomingCallRingtone.stop());
                                notifier.hangUp();
                              }
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
        return 'Calling…';
      case VoiceCallPhase.incomingRinging:
        return 'Incoming call…';
      case VoiceCallPhase.connecting:
        return 'Connecting…';
      case VoiceCallPhase.connected:
        return _formatDuration(state.connectedAt);
      case VoiceCallPhase.ended:
        final status = state.call?.status;
        // Caller sees a formal busy message when the peer declines.
        if (status == 'declined' && state.outgoing) {
          return '${state.peerName} is busy right now';
        }
        if (status == 'declined') return 'Call declined';
        if (status == 'cancelled') return 'Call cancelled';
        if (status == 'missed') return 'No answer';
        final lasted = _formatDuration(state.connectedAt);
        return lasted == '00:00' ? 'Call ended' : 'Call ended · $lasted';
      case VoiceCallPhase.failed:
        return 'Call failed';
    }
  }

  String _formatDuration(DateTime? started) {
    if (started == null) return '00:00';
    final duration = DateTime.now().difference(started);
    final total = duration.inSeconds.clamp(0, 24 * 3600);
    final minutes = (total ~/ 60).toString().padLeft(2, '0');
    final seconds = (total % 60).toString().padLeft(2, '0');
    if (total >= 3600) {
      final hours = (total ~/ 3600).toString().padLeft(2, '0');
      final m = ((total % 3600) ~/ 60).toString().padLeft(2, '0');
      return '$hours:$m:$seconds';
    }
    return '$minutes:$seconds';
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
            minimumSize: const Size(64, 64),
          ),
          icon: Icon(icon, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}
