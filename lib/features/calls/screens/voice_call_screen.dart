import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/root_back.dart';
import '../../privacy-mode/peer_privacy_provider.dart';
import '../../privacy-mode/privacy_secure_scope.dart';
import '../../../shared/widgets/app_toast.dart';
import '../audio/call_audio_devices.dart';
import '../audio/call_audio_output.dart';
import '../data/models/voice_call.dart';
import '../decline-message/decline_message_send.dart';
import '../incoming_call_ringtone.dart';
import '../native/android_call_screen_lock.dart';
import '../providers/voice_call_provider.dart';
import '../widgets/call_audio_output_sheet.dart';
import '../widgets/call_controls_row.dart';
import '../widgets/connected_call_body.dart';
import 'incoming_call_view.dart';
import '../../../core/localization/app_translations.dart';

/// The 1:1 call screen.
///
/// Back — and the minimise chevron — leave this screen and drop the user back
/// where they were, with `ActiveCallBanner` across the top: WhatsApp's model,
/// and what was asked for. It deliberately does **not** shrink into a
/// picture-in-picture window any more. Signal can do that because its call
/// owns an Activity; ours is the one FlutterActivity for the whole app, so
/// "minimise the call" shrank the entire app into a thumbnail and the return
/// bar never got a chance to show.
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
    // A call screen that sleeps on the system timeout leaves the user
    // unlocking the phone to hang up. Proximity blanking is separate and
    // tracks the call, not this screen — see AndroidCallScreenLock.
    unawaited(AndroidCallScreenLock.setKeepScreenOn(true));
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
    unawaited(AndroidCallScreenLock.setKeepScreenOn(false));
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

  /// Decline, then write [text] into the call's DM. The screen closes with
  /// the decline, so a failure is reported on the root overlay, which stays.
  void _declineWithMessage(VoiceCall session, String myUserId, String text) {
    final notifier = ref.read(voiceCallProvider.notifier);
    final lang = ref.read(appLanguageProvider);
    // Looked up now: this screen is gone by the time the send returns.
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    unawaited(IncomingCallRingtone.stop());
    unawaited(notifier.declineIncoming());
    unawaited(() async {
      final sent = await sendCallDeclineMessage(
        conversationId: session.conversationId,
        text: text,
        myUserId: myUserId,
      );
      if (sent) return;
      showAppToastIn(
        overlay,
        AppTranslations.of(lang, 'call_decline_message_failed'),
        isError: true,
      );
    }());
  }

  /// Leave the screen, not the call. `popOrGoHome` is what handles a call
  /// opened straight from a push, where there is no history to pop back into.
  void _leave() => popOrGoHome(context);

  @override
  Widget build(BuildContext context) {
    ref.listen(voiceCallProvider.select((s) => s.phase), (prev, next) {
      _syncRingtone(next);
      _scheduleAutoClose(next);
    });
    final call = ref.watch(voiceCallProvider);
    final notifier = ref.read(voiceCallProvider.notifier);
    final lang = ref.watch(appLanguageProvider);
    final audio =
        ref.watch(callAudioDevicesProvider).valueOrNull ??
        CallAudioDevices.empty;
    // The other side's privacy mode (server 0152): this phone must not
    // capture the call — ring, video and shared screen included. A flip
    // during the call (`chat.peer_privacy`) wins over the row's snapshot.
    final session = call.call;
    final peerPrivate =
        session != null &&
        (ref.watch(
              livePeerPrivacyProvider(session.peerId(call.currentUserId)),
            ) ??
            session.peerPrivate(call.currentUserId));

    if (call.phase == VoiceCallPhase.incomingRinging) {
      return PrivacySecureScope(
        active: peerPrivate,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          // The reply sheet lifts itself over the keyboard; resizing the
          // whole ringing screen under it would squash the caller's face.
          resizeToAvoidBottomInset: false,
          body: IncomingCallView(
            peerName: call.peerName,
            peerAvatar: call.peerAvatar,
            video: session?.isVideo ?? false,
            lang: lang,
            onSilence: IncomingCallRingtone.silence,
            onDeclineWithMessage: session == null
                ? null
                : (text) =>
                      _declineWithMessage(session, call.currentUserId, text),
            onDecline: () {
              unawaited(IncomingCallRingtone.stop());
              notifier.declineIncoming();
            },
            onAccept: () {
              unawaited(IncomingCallRingtone.stop());
              notifier.acceptIncoming();
            },
          ),
        ),
      );
    }

    // canPop stays false while the call is live so the pop runs through
    // [_leave] — a plain pop from a route with no history would strand the
    // user on a blank screen with a call still running.
    return PrivacySecureScope(
      active: peerPrivate,
      child: PopScope(
        canPop: !call.active,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _leave();
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: ConnectedCallBody(
            call: call,
            lang: lang,
            onMinimize: _leave,
            onSwitchCamera: notifier.switchCamera,
            controls: CallControlsRow(
              lang: lang,
              call: call,
              onToggleMute: notifier.toggleMute,
              onToggleCamera: notifier.toggleCamera,
              onToggleScreenShare: notifier.toggleScreenShare,
              audio: audio,
              onToggleSpeaker: () => unawaited(
                pressCallAudioOutput(
                  context,
                  audio,
                  lang: lang,
                  fallback: notifier.toggleSpeaker,
                ),
              ),
              onHangUp: () {
                unawaited(IncomingCallRingtone.stop());
                notifier.hangUp();
              },
            ),
          ),
        ),
      ),
    );
  }
}
