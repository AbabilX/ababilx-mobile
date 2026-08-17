part of 'group_call_provider.dart';

/// Native ringing for channel group calls — the DM behaviour, minus the parts
/// that do not exist here (there is no callee record, so "Ignore" is local and
/// never reaches the server).
///
/// Which UI rings is decided by app lifecycle, never by both at once:
/// foreground → the Flutter invite dialog + in-app tone; background, locked or
/// killed → CallKit's full-screen intent, which is the only thing Android lets
/// a backgrounded process raise.
mixin GroupCallCallkit on GroupCallBase, GroupCallLifecycle, GroupCallMedia {
  /// Implemented by [GroupCallNotifier].
  Future<void> join(String conversationId);
  Future<void> leave();

  void initNativeCallUi() {
    _nativeSub ??= FlutterCallkitIncoming.onEvent.listen(_handleNativeEvent);
  }

  Future<void> disposeNativeCallUi() async {
    await _nativeSub?.cancel();
    _nativeSub = null;
  }

  /// Puts the ringing invite on the right surface for the current lifecycle.
  /// Safe to call repeatedly — showing is deduped and hiding is a no-op when
  /// nothing native is up.
  Future<void> syncNativeInviteUi() async {
    final invite = state.invite;
    if (invite == null) {
      _invites?.setLocalRing(true);
      return;
    }
    if (flutterOwnsRingingUi) {
      // Dismiss first: tearing the native screen down drops its audio focus,
      // which would cut an in-app tone that had already started underneath it.
      await AndroidGroupCallUi.hideIncoming(invite.id);
      _invites?.setLocalRing(true);
      await CallRingtone.handoff();
      return;
    }
    _invites?.setLocalRing(false);
    await AndroidGroupCallUi.showIncomingFromCall(invite);
  }

  /// Accepting from a killed app relaunches the process, so the accept has to
  /// be picked back up here rather than from a live event stream.
  Future<void> recoverNativeAccept() async {
    if (state.active || _room != null) return;
    try {
      final active = await FlutterCallkitIncoming.activeCalls();
      for (final params in active) {
        if (!AndroidGroupCallUi.isGroupCall(params)) continue;
        final conversationId = AndroidGroupCallUi.conversationIdOf(params);
        if (conversationId.isEmpty) continue;
        if (params.isAccepted) {
          _invites?.markAnswered(params.id);
          await join(conversationId);
          return;
        }
        // Still ringing, unanswered. The socket may never have delivered
        // `group_call.started` to this device, so hand the ring to the in-app
        // invite rather than dropping it when CallKit is dismissed below.
        // GroupCallInvites re-checks the ring window and the answered set.
        final call = AndroidGroupCallUi.callFrom(params);
        if (call != null) _invites?.offer(call, currentUserId: _currentUserId);
        await syncNativeInviteUi();
        if (state.invite?.id != params.id) {
          await AndroidGroupCallUi.hideIncoming(params.id);
        }
        return;
      }
    } catch (_) {
      // No recoverable native group call.
    }
  }

  void _handleNativeEvent(CallEvent? event) {
    if (event == null) return;
    switch (event) {
      case CallEventActionCallAccept(:final callKitParams):
        if (!AndroidGroupCallUi.isGroupCall(callKitParams)) return;
        final conversationId = AndroidGroupCallUi.conversationIdOf(
          callKitParams,
        );
        _invites?.markAnswered(callKitParams.id);
        unawaited(AndroidGroupCallUi.hideIncoming(callKitParams.id));
        if (conversationId.isNotEmpty) unawaited(join(conversationId));
      case CallEventActionCallDecline(:final callKitParams):
        if (!AndroidGroupCallUi.isGroupCall(callKitParams)) return;
        // Local only: the call keeps running and the channel header still
        // offers Join.
        _invites?.markAnswered(callKitParams.id);
        unawaited(AndroidGroupCallUi.hideIncoming(callKitParams.id));
      case CallEventActionCallEnded(:final callKitParams):
        if (!AndroidGroupCallUi.isGroupCall(callKitParams)) return;
        if (state.call?.id == callKitParams.id) unawaited(leave());
      case CallEventActionCallTimeout(:final id):
        // Timeout carries no params, so fall back to matching the ringing id.
        if (state.invite?.id == id) _invites?.dismiss();
      case CallEventActionCallToggleMute(:final id, :final isMuted):
        if (state.call?.id == id && state.muted != isMuted) {
          unawaited(toggleMute());
        }
      default:
        break;
    }
  }
}
