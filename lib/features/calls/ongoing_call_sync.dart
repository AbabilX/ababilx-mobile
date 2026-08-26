import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'group/providers/group_call_provider.dart';
import 'native/android_ongoing_call.dart';
import 'providers/voice_call_provider.dart';
import 'voice_call_log.dart';

/// Mirrors call state onto the Android ongoing-call notification, and routes
/// the two presses it can produce back into the app.
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

  /// Which call the notification is currently describing, so a state rebuild
  /// that changes nothing relevant does not re-post it.
  String _shownCallId = '';

  @override
  void initState() {
    super.initState();
    _actions = AndroidOngoingCall.actions.listen(_onAction);
  }

  @override
  void dispose() {
    unawaited(_actions?.cancel());
    unawaited(AndroidOngoingCall.stop());
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
  void _sync(VoiceCallState dm, GroupCallState group) {
    if (dm.phase == VoiceCallPhase.connected && dm.call != null) {
      _show(dm.call!.id, dm.call!.peerName(dm.currentUserId), 'Ongoing call');
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
      );
      return;
    }
    if (_shownCallId.isEmpty) return;
    _shownCallId = '';
    unawaited(AndroidOngoingCall.stop());
  }

  void _show(String callId, String title, String subtitle) {
    if (_shownCallId == callId) return;
    _shownCallId = callId;
    unawaited(
      AndroidOngoingCall.start(
        callId: callId,
        title: title,
        subtitle: subtitle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dm = ref.watch(voiceCallProvider);
    final group = ref.watch(groupCallProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync(dm, group);
    });
    return widget.child;
  }
}
