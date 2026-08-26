import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/root_back.dart';
import '../call_status_text.dart';
import '../incoming_call_ringtone.dart';
import '../native/android_pip.dart';
import '../providers/voice_call_provider.dart';
import '../widgets/call_controls_row.dart';
import '../widgets/connected_call_body.dart';
import '../widgets/pip_call_view.dart';
import '../widgets/remote_screen_view.dart';
import 'incoming_call_view.dart';

/// The 1:1 call screen.
///
/// Back does not leave a running call. Signal shrinks its call Activity into a
/// floating window instead of finishing it, so a live call always has a
/// surface; we do the same through [AndroidPip], and fall back to the ordinary
/// pop only when the device refuses to shrink (or the call is already over).
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
      final phase = ref.read(voiceCallProvider).phase;
      _syncRingtone(phase);
      _syncPip(phase);
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _autoClose?.cancel();
    unawaited(IncomingCallRingtone.stop());
    unawaited(AndroidPip.setActive(false));
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

  /// Arm PiP for everything except a ringing call: Signal never shrinks an
  /// incoming call either, because a thumbnail has nowhere to put Answer.
  void _syncPip(VoiceCallPhase phase) {
    final shrinkable =
        phase == VoiceCallPhase.connected ||
        phase == VoiceCallPhase.connecting ||
        phase == VoiceCallPhase.outgoingRinging;
    unawaited(AndroidPip.setActive(shrinkable));
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

  Future<void> _leave() async {
    if (await AndroidPip.enter()) return;
    if (mounted) popOrGoHome(context);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(voiceCallProvider.select((s) => s.phase), (prev, next) {
      _syncRingtone(next);
      _syncPip(next);
      _scheduleAutoClose(next);
    });
    final call = ref.watch(voiceCallProvider);
    final notifier = ref.read(voiceCallProvider.notifier);

    return ValueListenableBuilder<bool>(
      valueListenable: AndroidPip.inPip,
      builder: (context, inPip, _) {
        if (inPip) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: PipCallView(
              name: call.peerName,
              avatarUrl: call.peerAvatar,
              status: voiceCallStatusText(call),
              screenShare: call.remoteScreenStream == null
                  ? null
                  : RemoteScreenView(stream: call.remoteScreenStream!),
            ),
          );
        }

        if (call.phase == VoiceCallPhase.incomingRinging) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: IncomingCallView(
              peerName: call.peerName,
              peerAvatar: call.peerAvatar,
              onDecline: () {
                unawaited(IncomingCallRingtone.stop());
                notifier.declineIncoming();
              },
              onAccept: () {
                unawaited(IncomingCallRingtone.stop());
                notifier.acceptIncoming();
              },
            ),
          );
        }

        return PopScope(
          canPop: !call.active,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            unawaited(_leave());
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            body: ConnectedCallBody(
              call: call,
              onMinimize: _leave,
              controls: CallControlsRow(
                call: call,
                onToggleMute: notifier.toggleMute,
                onToggleScreenShare: notifier.toggleScreenShare,
                onToggleSpeaker: notifier.toggleSpeaker,
                onHangUp: () {
                  unawaited(IncomingCallRingtone.stop());
                  notifier.hangUp();
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
