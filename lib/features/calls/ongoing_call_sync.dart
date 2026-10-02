import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:call_ringer/call_ringer.dart';
import 'package:go_router/go_router.dart';

import 'group/providers/group_call_provider.dart';
import 'live_call.dart';
import 'native/android_call_ringback.dart';
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

class _OngoingCallSyncState extends ConsumerState<OngoingCallSync>
    with WidgetsBindingObserver {
  StreamSubscription<OngoingCallAction>? _actions;
  Timer? _notificationRetry;
  String _pendingKey = '';
  int _notificationEpoch = 0;
  int _retryAttempt = 0;

  /// What the notification is currently saying — call id and subtitle — so a
  /// state change that alters neither does not re-post it.
  String _shownKey = '';

  /// Whether the one unconditional stop has been sent yet.
  ///
  /// The Activity can be destroyed while a call is running — the OS reclaiming
  /// it, "Don't keep activities" — and that takes the FlutterEngine and the
  /// whole WebRTC session with it while [OngoingCallService] keeps running in
  /// the surviving process. The shade then shows a call this app no longer
  /// has: no return bar, no call screen, and tapping the notification does
  /// nothing, because there is nothing to return to. A fresh sync knows only
  /// its own [_shownKey] (empty), so without this it would leave that entry up
  /// forever.
  bool _clearedOrphan = false;

  /// When this device first saw the group call connected. `GroupCall` carries
  /// no join time of its own, and the chronometer needs one that does not move
  /// each time the notification is restated.
  String _groupCallId = '';
  DateTime? _groupConnectedAt;

  /// Last value sent to [CallRinger.setLiveCall]; `'?'` = nothing sent yet.
  String? _liveCallSent = '?';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.removeObserver(this);
    _notificationRetry?.cancel();
    unawaited(_actions?.cancel());
    unawaited(AndroidOngoingCall.stop());
    unawaited(AndroidCallScreenLock.setEarpieceCall(false));
    unawaited(AndroidCallRingback.stop());
    unawaited(CallRinger.setLiveCall(null));
    super.dispose();
  }

  /// Android can revoke a foreground entry or stop its service while the app
  /// is away. Resume is the reliable reconciliation boundary: re-state the
  /// still-live call even when Riverpod state itself did not change.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    _shownKey = '';
    _pendingKey = '';
    _notificationRetry?.cancel();
    _notificationRetry = null;
    _sync();
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
      case OngoingCallAction.screenShareStopped:
        voiceCallLog('ongoing.screenShare.systemStop');
        unawaited(
          ref.read(voiceCallProvider.notifier).endScreenShareFromSystem(),
        );
        unawaited(
          ref.read(groupCallProvider.notifier).endScreenShareFromSystem(),
        );
      case OngoingCallAction.returnToCall:
        voiceCallLog('ongoing.notification.return');
        if (ref.read(voiceCallProvider).active) {
          widget.router.go('/call');
        } else if (ref.read(groupCallProvider).phase != GroupCallPhase.idle) {
          widget.router.go('/group-call');
        } else {
          // The entry outlived the call it was posted for. Take it down rather
          // than open a call screen with no call behind it.
          voiceCallLog('ongoing.notification.orphan');
          _clearNotificationState();
          unawaited(AndroidOngoingCall.stop(force: true));
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
    _syncLiveCall(dm, group);
    unawaited(AndroidCallRingback.sync(dm));
    final dmCall = dm.call;
    final dmSubtitle = ongoingCallSubtitle(
      dm.phase,
      remoteRinging: dmCall?.calleeRingingAt != null,
    );
    if (dmCall != null && dmSubtitle != null) {
      _show(
        dmCall.id,
        dmCall.peerName(dm.currentUserId),
        dmSubtitle,
        connected: ongoingCallUsesChronometer(dm.phase),
        connectedAt: dm.connectedAt,
      );
      return;
    }
    if (group.phase == GroupCallPhase.connected && group.call != null) {
      final call = group.call!;
      if (_groupCallId != call.id || _groupConnectedAt == null) {
        _groupCallId = call.id;
        _groupConnectedAt = DateTime.now();
      }
      _show(
        call.id,
        call.conversationName?.trim().isNotEmpty == true
            ? call.conversationName!
            : 'Group call',
        'Ongoing group call',
        connected: true,
        connectedAt: _groupConnectedAt,
      );
      return;
    }
    _groupCallId = '';
    _groupConnectedAt = null;
    if (_shownKey.isEmpty && _clearedOrphan) return;
    _clearedOrphan = true;
    _clearNotificationState();
    unawaited(AndroidOngoingCall.stop(force: true));
  }

  /// The screen blanks at the ear — Signal's `LockManager` `IN_CALL`: an
  /// outgoing call from the moment it rings (Signal enters `IN_CALL` then),
  /// while it connects, and once connected. An INCOMING ring is excluded:
  /// that is a call the user is looking at. Video on either side is Signal's
  /// `IN_VIDEO` and keeps the screen on.
  ///
  /// Whether the call is hands-free (speaker, Bluetooth, wired headset) is
  /// decided natively from the call's audio route (`CallHandsFree.kt`), so a
  /// picker choice or a headset plugged in mid-call flips the lock without
  /// Dart having to notice.
  void _syncProximity(VoiceCallState dm, GroupCallState group) {
    final dmAtEar = switch (dm.phase) {
      VoiceCallPhase.outgoingRinging ||
      VoiceCallPhase.connecting ||
      VoiceCallPhase.connected => true,
      _ => false,
    };
    final dmVideo =
        dm.cameraOn ||
        dm.remoteCameraStream != null ||
        dm.remoteScreenStream != null ||
        dm.screenSharing;
    final atEar =
        (dmAtEar && !dmVideo) || group.phase == GroupCallPhase.connected;
    unawaited(AndroidCallScreenLock.setEarpieceCall(atEar));
  }

  /// Signal's busy rule, told to the process: entering a call stops every
  /// ring at once (the "still ringing after I answered" report), and no push
  /// can ring or raise a ringing screen until the call is left.
  void _syncLiveCall(VoiceCallState dm, GroupCallState group) {
    final live = liveCallId(dm, group);
    if (live == _liveCallSent) return;
    _liveCallSent = live;
    voiceCallLog(
      'busy.live',
      callId: live,
      reason: live == null ? 'idle' : 'in_call',
    );
    unawaited(CallRinger.setLiveCall(live));
  }

  void _show(
    String callId,
    String title,
    String subtitle, {
    required bool connected,
    DateTime? connectedAt,
  }) {
    final since = connectedAt?.millisecondsSinceEpoch ?? 0;
    final key = '$callId|$title|$subtitle|$connected|$since';
    if (_shownKey == key || _pendingKey == key) return;
    _notificationRetry?.cancel();
    _notificationRetry = null;
    _pendingKey = key;
    final epoch = ++_notificationEpoch;
    unawaited(
      _postNotification(
        epoch: epoch,
        key: key,
        callId: callId,
        title: title,
        subtitle: subtitle,
        connected: connected,
        connectedAt: connectedAt,
      ),
    );
  }

  Future<void> _postNotification({
    required int epoch,
    required String key,
    required String callId,
    required String title,
    required String subtitle,
    required bool connected,
    DateTime? connectedAt,
  }) async {
    final ready = await AndroidOngoingCall.start(
      callId: callId,
      title: title,
      subtitle: subtitle,
      connected: connected,
      connectedAt: connectedAt,
    );
    if (!mounted || epoch != _notificationEpoch) return;
    _pendingKey = '';
    if (ready) {
      _shownKey = key;
      _retryAttempt = 0;
      _clearedOrphan = false;
      return;
    }

    // Foreground starts may be rejected during a lifecycle transition. Retry
    // while the call remains live, with a ceiling to avoid a hot background
    // loop. Resume always resets this and retries immediately.
    final delay = ongoingCallRetryDelay(_retryAttempt);
    _retryAttempt++;
    voiceCallLog('ongoing.notification.retry attempt=$_retryAttempt');
    _notificationRetry = Timer(delay, _sync);
  }

  void _clearNotificationState() {
    _notificationEpoch++;
    _notificationRetry?.cancel();
    _notificationRetry = null;
    _pendingKey = '';
    _shownKey = '';
    _retryAttempt = 0;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
