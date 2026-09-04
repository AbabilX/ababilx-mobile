import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'group/providers/group_call_provider.dart';
import 'native/android_call_screen_lock.dart';
import 'native/android_ongoing_call.dart';
import 'ongoing_call_notice.dart';
import 'providers/voice_call_provider.dart';
import 'voice_call_log.dart';

/// Mirrors call state onto the pieces of Android that outlive the call
/// screen: the ongoing-call notification (and the two presses it can produce),
/// and the proximity lock that blanks the display at the ear.
///
/// This is what makes a call survive leaving its screen. Before it existed,
/// popping `/call` (the back gesture, a deep link, anything) left a live
/// WebRTC session with no surface: the user could not get back to it and could
/// not end it — the call ran until the other side hung up or the server
/// sweeper expired it.
///
/// It lives beside `CallStoreSync` rather than inside it because that widget
/// is already at its size limit, and because these are genuinely different
/// jobs: `CallStoreSync` decides which screen to show, this decides what the
/// notification shade says while no screen is shown at all.
class OngoingCallSync extends ConsumerStatefulWidget {
  const OngoingCallSync({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<OngoingCallSync> createState() => _OngoingCallSyncState();
}

class _OngoingCallSyncState extends ConsumerState<OngoingCallSync> {
  StreamSubscription<OngoingCallAction>? _actions;

  /// What the notification is currently saying — call id and subtitle — so a
  /// state change that alters neither does not re-post it.
  String _shownKey = '';

  @override
  void initState() {
    super.initState();
    _actions = AndroidOngoingCall.actions.listen(_onAction);
    // Deliberately `listenManual` and not `ref.watch` in `build`: this sync
    // has to run while the app is in the background, and a backgrounded
    // Flutter app schedules no frames. Driven from `build` + a post-frame
    // callback, hanging up from the shade tore the call down but left its
    // notification sitting there until the user opened the app again — which
    // reads exactly like the hang up having done nothing.
    _watch(voiceCallProvider);
    _watch(groupCallProvider);
  }

  void _watch<T>(ProviderListenable<T> provider) {
    ref.listenManual<T>(provider, (_, _) => _sync(), fireImmediately: true);
  }

  @override
  void dispose() {
    unawaited(_actions?.cancel());
    unawaited(AndroidOngoingCall.stop());
    unawaited(AndroidCallScreenLock.setEarpieceCall(false));
    super.dispose();
  }

  void _onAction(OngoingCallAction action) {
    if (!mounted) return;
    switch (action) {
      case OngoingCallAction.hangUp:
        voiceCallLog('ongoing.notification.hangUp');
        if (ref.read(voiceCallProvider).active) {
          unawaited(
            ref
                .read(voiceCallProvider.notifier)
                .hangUp(source: 'ongoingNotification'),
          );
          return;
        }
        if (ref.read(groupCallProvider).phase == GroupCallPhase.connected) {
          unawaited(ref.read(groupCallProvider.notifier).leave());
        }
      case OngoingCallAction.returnToCall:
        voiceCallLog('ongoing.notification.return');
        if (ref.read(voiceCallProvider).active) {
          widget.router.go('/call');
        } else if (ref.read(groupCallProvider).phase != GroupCallPhase.idle) {
          widget.router.go('/group-call');
        }
    }
  }

  /// The DM call wins when both somehow exist: it is the one whose audio is
  /// live on the earpiece.
  void _sync() {
    if (!mounted) return;
    final dm = ref.read(voiceCallProvider);
    final group = ref.read(groupCallProvider);
    _syncProximity(dm, group);
    final dmCall = dm.call;
    final dmSubtitle = ongoingCallSubtitle(dm.phase);
    if (dmCall != null && dmSubtitle != null) {
      _show(
        dmCall.id,
        dmCall.peerName(dm.currentUserId),
        dmSubtitle,
        connected: ongoingCallUsesChronometer(dm.phase),
      );
      return;
    }
    if (group.phase == GroupCallPhase.connected && group.call != null) {
      final call = group.call!;
      _show(
        call.id,
        call.conversationName?.trim().isNotEmpty == true
            ? call.conversationName!
            : 'Group call',
        'Ongoing group call',
        connected: true,
      );
      return;
    }
    if (_shownKey.isEmpty) return;
    _shownKey = '';
    unawaited(AndroidOngoingCall.stop());
  }

  /// The screen blanks at the ear only for a call that is actually up and
  /// actually on the earpiece — Signal's `LockManager` engages proximity in
  /// `IN_CALL` and nowhere else. A ringing call is one the user is looking at,
  /// and a call on speaker is one the phone is nowhere near.
  ///
  /// Headsets are not checked here: the native side watches the audio devices
  /// itself, so a headset plugged in mid-call gives the screen back without
  /// Dart having to notice.
  void _syncProximity(VoiceCallState dm, GroupCallState group) {
    final earpiece =
        (dm.phase == VoiceCallPhase.connected && !dm.speaker) ||
        (group.phase == GroupCallPhase.connected && !group.speaker);
    unawaited(AndroidCallScreenLock.setEarpieceCall(earpiece));
  }

  void _show(
    String callId,
    String title,
    String subtitle, {
    required bool connected,
  }) {
    final key = '$callId|$subtitle';
    if (_shownKey == key) return;
    _shownKey = key;
    unawaited(
      AndroidOngoingCall.start(
        callId: callId,
        title: title,
        subtitle: subtitle,
        connected: connected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
