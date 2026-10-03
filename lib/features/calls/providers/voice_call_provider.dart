import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../decline-message/decline_message_send.dart';
import '../../../core/network/ws_client.dart';
import '../../messages/data/models/chat_conversation.dart';
import '../../profile/providers/profile_provider.dart';
import '../audio/call_audio_devices.dart';
import '../audio/call_audio_output.dart';
import '../audio/call_audio_route.dart';
import '../call_lifecycle.dart';
import '../call_lookup_failure.dart';
import '../call_lookup_retry.dart';
import '../call_permissions.dart';
import '../call_trace.dart';
import '../callkit_ended_suppress.dart';
import '../data/models/voice_call.dart';
import '../data/models/voice_call_session.dart';
import '../data/voice_call_repository.dart';
import '../incoming_call_ringtone.dart';
import '../native/android_call_ui.dart';
import '../native/android_group_call_ui.dart';
import '../native/incoming_call_admission.dart';
import '../native/native_call_events.dart';
import '../native/answered_elsewhere.dart';
import '../native/call_answered_guard.dart';
import '../native/call_ringing_ack.dart';
import '../native/voice_call_ended_guard.dart';
import '../ringtone/callkit_ring_events.dart';
import '../voice_call_heartbeat.dart';
import '../voice_call_log.dart';
import '../voice_call_ringable.dart';
import '../webrtc/voice_peer_engine.dart';
import '../webrtc/voice_peer_engine_factory.dart';
import '../webrtc/voice_reconnect_controller.dart';
import 'call_identity.dart';
import 'voice_call_state.dart';

export 'voice_call_state.dart';

class VoiceCallNotifier extends Notifier<VoiceCallState> {
  StreamSubscription<Map<String, dynamic>>? _wsSub;
  StreamSubscription<void>? _wsReconnectSub;
  StreamSubscription<CallEvent?>? _nativeSub;
  StreamSubscription<RemoteMessage>? _foregroundPushSub;
  VoicePeerEngine? _engine;

  /// The call the engine — prepared or still being prepared — was built for.
  ///
  /// State cannot answer this on its own. A decline, a heartbeat reply or a
  /// teardown names the call it is about, and by the time it runs the call in
  /// state may be the NEXT one. Everything that disposes media asks this
  /// first, so work started for one call never takes another call's engine.
  String? _engineCallId;

  /// Proof of life for the server, so an accepted call cannot outlive the two
  /// devices on it. See [VoiceCallHeartbeat].
  late final VoiceCallHeartbeat _heartbeat = VoiceCallHeartbeat(
    send: (callId) async =>
        (await _repository.action(callId, 'heartbeat')).call,
    onEndedRemotely: (call) => unawaited(
      _finishLocal(
        call.status == 'ended' ? VoiceCallPhase.ended : VoiceCallPhase.failed,
        reason: 'heartbeat.${call.status}',
        callId: call.id,
      ),
    ),
  );
  VoiceReconnectController? _reconnect;
  final List<Map<String, dynamic>> _pendingSignals = [];
  Timer? _ringTimer;
  Timer? _resetTimer;
  Timer? _connectWatchdog;
  Timer? _renegotiateTimer;
  bool _booted = false;
  bool _transitioning = false;
  int _operation = 0;
  bool _ending = false;
  VoicePeerEngine? _preparingEngine;
  bool _offerResent = false;

  /// Bounded re-asks for a call lookup that failed without saying anything
  /// about the call (no network, a timeout, a 5xx).
  late final CallLookupRetry _lookupRetry = CallLookupRetry(
    delays: lookupRetryDelays,
  );

  /// Who is making the next state write, for the trace.
  String? _writeSource;

  /// The call this device is answering whose accept the server has not
  /// confirmed yet. Hanging up in that window declines rather than ends.
  String? _answeringCallId;
  final Set<String> _finishedCallIds = {};
  final Set<String> _remoteRingingCallIds = {};
  final CallKitEndedSuppress _suppressCallKitEnded = CallKitEndedSuppress();

  /// Watchdog window from entering `connecting` until the engine is prepared.
  static const _setupBudget = Duration(seconds: 50);

  VoiceCallRepository get _repository => ref.read(voiceCallRepositoryProvider);
  WsClient get _ws => ref.read(wsClientProvider);

  String get _phaseName => state.phase.name;

  /// How long a finished call stays on screen before the return to idle.
  @visibleForTesting
  Duration get resetDelay => const Duration(seconds: 5);

  /// Backoff between re-asks of a call lookup that failed in transit.
  @visibleForTesting
  List<Duration> get lookupRetryDelays => CallLookupRetry.defaultDelays;

  @visibleForTesting
  int get debugOperation => _operation;

  @visibleForTesting
  String? get debugEngineCallId => _engineCallId;

  @visibleForTesting
  bool get debugHasEngine => _engine != null || _preparingEngine != null;

  @visibleForTesting
  bool get debugResetPending => _resetTimer?.isActive ?? false;

  /// Every change of phase or call is traced with the engine's owner beside
  /// it, so "who took this call to idle" is one line in the log.
  @override
  set state(VoiceCallState next) {
    final previous = state;
    final source = _writeSource;
    _writeSource = null;
    super.state = next;
    final previousId = previous.call?.id;
    final nextId = next.call?.id;
    if (previous.phase == next.phase && previousId == nextId) return;
    callTrace(
      'STATE_CHANGED',
      callId: nextId ?? previousId,
      previousPhase: previous.phase.name,
      newPhase: next.phase.name,
      engineCallId: _engineCallId,
      generation: _operation,
      source: source,
      reason: previousId != null && nextId != null && previousId != nextId
          ? 'replaced=$previousId'
          : null,
    );
  }

  /// A state write that names who made it.
  void _write(VoiceCallState next, String source) {
    _writeSource = source;
    state = next;
  }

  /// True while a call other than [callId] holds this device: media exists or
  /// is being set up for it, or it is being placed, answered or talked on.
  /// The same phases `liveCallId` reports to the process as busy — a ring in
  /// progress is not live, it is only on offer.
  bool _holdsLiveCallOtherThan(String callId) {
    if ((_engine != null || _preparingEngine != null) &&
        _engineCallId != callId) {
      return true;
    }
    final current = state.call;
    if (current == null || current.id == callId) return false;
    return state.phase == VoiceCallPhase.outgoingRinging ||
        state.phase == VoiceCallPhase.connecting ||
        state.phase == VoiceCallPhase.connected;
  }

  /// Work that began for [targetCallId] reached a point where the call in
  /// state, or the engine, belongs to another call — and was refused there.
  void _traceStale(String operation, String targetCallId, {String? reason}) {
    callTrace(
      'STALE_CALL_OPERATION',
      operation: operation,
      targetCallId: targetCallId,
      activeCallId: state.call?.id,
      engineCallId: _engineCallId,
      previousPhase: _phaseName,
      generation: _operation,
      reason: reason,
    );
  }

  /// A new call is about to take the state machine. Nothing an earlier call
  /// left scheduled or queued may reach it: its 5 s reset would wipe the new
  /// call mid-ring — or mid-call, leaving live media with no screen — and a
  /// signal still queued for it would be fed to the wrong peer connection.
  void _claimStateFor(String callId, {required String source}) {
    _cancelReset('claimed.$source', callId: callId);
    _lookupRetry.cancel();
    _pendingSignals.clear();
  }

  @override
  VoiceCallState build() {
    ref.onDispose(dispose);
    final userId = ref.read(profileProvider).valueOrNull?.id ?? '';
    ref.listen(profileProvider, (_, next) {
      final id = next.valueOrNull?.id;
      if (id != null && id.isNotEmpty) {
        state = state.copyWith(currentUserId: id);
      }
    });
    // The native audio owner moved the call (a headset connected, a pick in
    // the output sheet): `speaker` follows what is actually playing.
    ref.listen(callAudioDevicesProvider, (_, next) {
      final devices = next.valueOrNull;
      if (devices == null || !devices.known || !state.active) return;
      final speaker = devices.active == CallAudioOutput.speaker;
      if (speaker != state.speaker) state = state.copyWith(speaker: speaker);
    });
    return VoiceCallState(currentUserId: userId);
  }

  Future<void> bootstrap() async {
    if (_booted) return;
    _booted = true;
    _wsSub = _ws.events.listen(_handleWsEvent);
    _wsReconnectSub = _ws.reconnects.listen((_) {
      unawaited(resyncActiveCall());
    });
    _nativeSub = NativeCallEvents.stream.listen(_handleNativeEvent);
    _foregroundPushSub = FirebaseMessaging.onMessage.listen(
      _handleForegroundCallPush,
    );
    await _ws.connect();
    unawaited(prewarmCallPermissions());
    unawaited(_ensureIdentity());
    // Not `_recoverNativeCall` alone: the socket connected above replays
    // `call.incoming` for a call still ringing on the server, so by now state
    // may already hold it as ringing — and recovery skips an active call. The
    // sync adopts an Accept CallKit recorded before this engine existed.
    await syncFromNativeIncoming();
  }

  /// The profile's first load on a fresh install can fail, and nothing retries
  /// it. Calls take their own side from the call row now, but the names on
  /// the call screen and the CallKit surface still come from this id.
  Future<void> _ensureIdentity() async {
    if (state.currentUserId.isNotEmpty) return;
    try {
      final me = await ref.read(profileProvider.future);
      if (me.id.isNotEmpty && state.currentUserId.isEmpty) {
        state = state.copyWith(currentUserId: me.id);
      }
      return;
    } catch (_) {
      // Fall through to a fresh read.
    }
    try {
      await ref.read(profileProvider.notifier).refresh();
    } catch (_) {
      // Offline: the call row still supplies the id when a call starts.
    }
  }

  Future<void> shutdown() async {
    if (!_booted) return;
    _booted = false;
    _operation++;
    _ringTimer?.cancel();
    _resetTimer?.cancel();
    _connectWatchdog?.cancel();
    _renegotiateTimer?.cancel();
    await _wsSub?.cancel();
    await _wsReconnectSub?.cancel();
    await _nativeSub?.cancel();
    await _foregroundPushSub?.cancel();
    _wsSub = null;
    _wsReconnectSub = null;
    _nativeSub = null;
    _foregroundPushSub = null;
    final callId = state.call?.id;
    final currentUserId = state.currentUserId;
    if (callId != null) await _endNative(callId, source: 'shutdown');
    await _resetResources();
    _suppressCallKitEnded.clear();
    _finishedCallIds.clear();
    _write(VoiceCallState(currentUserId: currentUserId), 'shutdown');
  }

  /// [video] places a video call: the camera opens with the call on both
  /// sides and the callee's ring screen says so. Media is still peer-to-peer.
  Future<void> startOutgoing(
    ChatConversation conversation, {
    bool video = false,
  }) async {
    if (state.active || _transitioning || _ending || !conversation.isDm) return;
    if (!conversation.canMessage || conversation.peerUserId == null) {
      state = state.copyWith(
        phase: VoiceCallPhase.failed,
        error: 'This person is no longer available.',
      );
      return;
    }
    final operation = ++_operation;
    _transitioning = true;
    try {
      await _resetResources();
      if (operation != _operation) return;
      state = VoiceCallState(
        phase: VoiceCallPhase.starting,
        currentUserId: state.currentUserId,
        pendingConversationId: conversation.id,
        pendingPeerName: conversation.peerUserName,
        pendingPeerAvatar: conversation.peerUserAvatar,
        pendingVideo: video,
      );
      voiceCallLog(
        'start.permission',
        phase: _phaseName,
        source: 'startOutgoing',
      );
      await _ensureCallPermissions();
      if (video) await _ensureCameraPermission();
      if (operation != _operation) return;
      voiceCallLog('start.api.begin', source: 'startOutgoing');
      final session = await _startWithStaleRecovery(conversation.id, video);
      voiceCallLog(
        'start.api.ok',
        callId: session.call.id,
        phase: 'outgoingRinging',
      );
      if (operation != _operation) {
        await _endCancelledServerCall(session.call.id);
        return;
      }
      final ringingEarly = _remoteRingingCallIds.remove(session.call.id);
      state = VoiceCallState(
        phase: VoiceCallPhase.outgoingRinging,
        call: ringingEarly && session.call.calleeRingingAt == null
            ? session.call.copyWith(calleeRingingAt: DateTime.now())
            : session.call,
        iceServers: session.iceServers,
        // Same call as "Calling…": a Speaker press made there still stands.
        speaker: state.speaker,
        speakerChosen: state.speakerChosen,
        // The account that placed the call is its caller, by definition. The
        // profile is not a safe source here: on a fresh install its first load
        // can fail and is never retried, and an empty id made `outgoing` false
        // — so this phone never sent the offer and the call sat on
        // "Connecting…" until a restart loaded the cached profile.
        currentUserId: callIdentity(
          state.currentUserId,
          session.call.callerId,
          source: 'start',
        ),
      );
      await AndroidCallUi.startOutgoing(session.call, state.currentUserId);
      if (operation != _operation) {
        await _endNative(session.call.id, source: 'start.cancelled');
        return;
      }
      _startRingTimer(session.call);
    } catch (error) {
      if (operation != _operation) return;
      voiceCallLog(
        'start.failed',
        reason: _debugError(error),
        source: 'startOutgoing',
      );
      await _resetResources();
      if (operation != _operation) return;
      state = state.copyWith(
        phase: VoiceCallPhase.failed,
        error: _friendlyError(error),
      );
      _scheduleReset();
    } finally {
      if (operation == _operation) _transitioning = false;
    }
  }

  Future<void> acceptIncoming([String? callId]) async {
    if (callId != null && _wasFinished(callId)) {
      await _endNative(callId, source: 'accept.finished');
      return;
    }
    if (_transitioning || _ending) {
      voiceCallLog(
        'accept.skip',
        callId: callId,
        phase: _phaseName,
        reason: 'transitioning',
      );
      return;
    }
    // Duplicate Accept while already connecting must not dismiss CallKit.
    if (state.phase == VoiceCallPhase.connecting ||
        state.phase == VoiceCallPhase.connected) {
      if (callId == null || state.call?.id == callId) {
        voiceCallLog(
          'accept.skip',
          callId: callId ?? state.call?.id,
          phase: _phaseName,
          reason: 'already_active',
        );
        return;
      }
    }

    var call = state.call;
    VoiceCallSession? adopted;
    if (call == null || (callId != null && call.id != callId)) {
      if (callId == null || callId.isEmpty) return;
      // Everything from here to `++_operation` only decides whether this
      // Accept is real, and none of it may disturb a call that is. The
      // counter used to move first: an Accept for a stale call aborted the
      // live call's own in-flight work before anything had been checked.
      if (_holdsLiveCallOtherThan(callId)) {
        _traceStale('accept', callId, reason: 'busy');
        await _endNative(callId, source: 'accept.busy');
        return;
      }
      final before = _operation;
      final VoiceCallSession session;
      try {
        session = await _repository.get(callId);
      } catch (error) {
        await _onLookupFailed(
          callId,
          error,
          source: 'accept',
          retry: () => acceptIncoming(callId),
          // Short on purpose: answering a call long after the press, with
          // nothing on screen in between, would open the microphone on
          // someone who has moved on. Past this, the Accept that CallKit
          // recorded is picked up again when the app next comes forward.
          retries: 2,
        );
        return;
      }
      _lookupRetry.settle(callId);
      // The answer can be late: something else may have moved on meanwhile.
      if (before != _operation || _wasFinished(callId)) return;
      if (_holdsLiveCallOtherThan(callId)) {
        _traceStale('accept', callId, reason: 'busy_after_lookup');
        await _endNative(callId, source: 'accept.busy');
        return;
      }
      call = session.call;
      // A CallKit surface outlives the call it announced: the plugin's
      // full-screen Activity cannot be closed by its own teardown (see
      // `CallkitSurface`), so a locked phone could still be showing an offer
      // the caller cancelled minutes ago. Answering that is not an accept.
      // Publishing `incomingRinging` first — as this did — sent CallStoreSync
      // to `/call` and started the in-app ringtone, and the not-ringing guard
      // further down only tore the *native* surface away, leaving a second
      // ringing screen with Accept and Decline that nothing could dismiss.
      if (!isVoiceCallRingable(call)) {
        voiceCallLog(
          'accept.stale_native',
          callId: call.id,
          phase: _phaseName,
          reason: 'status_${call.status}',
        );
        _rememberFinished(call.id);
        await _endNative(call.id, source: 'accept.stale_native');
        return;
      }
      adopted = session;
    }

    final operation = ++_operation;
    callTrace(
      'CALL_ACCEPT',
      callId: call.id,
      activeCallId: state.call?.id,
      engineCallId: _engineCallId,
      previousPhase: _phaseName,
      generation: operation,
      source: adopted == null ? 'state' : 'lookup',
    );
    if (adopted != null) {
      _claimStateFor(call.id, source: 'accept');
      _write(
        VoiceCallState(
          phase: VoiceCallPhase.incomingRinging,
          call: call,
          iceServers: adopted.iceServers,
          currentUserId: state.currentUserId,
        ),
        'accept.adopt',
      );
    }

    // Cancel ring timer before any await so a queued timeout cannot finishLocal.
    _ringTimer?.cancel();
    _ringTimer = null;

    if (call.status != 'ringing' || call.expiresAt.isBefore(DateTime.now())) {
      // Already accepted locally — keep WebRTC; do not endCall.
      if (state.call?.id == call.id &&
          (state.phase == VoiceCallPhase.connecting ||
              state.phase == VoiceCallPhase.connected)) {
        voiceCallLog(
          'accept.skip',
          callId: call.id,
          phase: _phaseName,
          reason: 'status_${call.status}_but_local_active',
        );
        return;
      }
      voiceCallLog(
        'accept.reject_local',
        callId: call.id,
        phase: _phaseName,
        reason: 'status_${call.status}',
      );
      // Finish, not just dismiss: `_endNative` closes CallKit and leaves this
      // notifier wherever it stood. Anything already showing `/call` for this
      // call would sit there ringing with no event left to end it.
      if (state.call?.id == call.id) {
        await _finishLocal(
          VoiceCallPhase.ended,
          reason: 'accept.not_ringing',
          callId: call.id,
        );
      } else {
        await _endNative(call.id, source: 'accept.not_ringing');
      }
      return;
    }

    _transitioning = true;
    voiceCallLog(
      'accept.begin',
      callId: call.id,
      phase: _phaseName,
      source: 'acceptIncoming',
    );
    // Answering starts now, not when the server confirms it. Held in
    // `incomingRinging` for the round trip, the call screen drew the ringing
    // view — Accept, Decline and the ringtone — so an Accept pressed on the
    // notification opened the app onto a second ring. On a cold start that
    // trip includes the whole boot, which is why it was "sometimes".
    _answeringCallId = call.id;
    state = state.copyWith(phase: VoiceCallPhase.connecting);
    _startConnectWatchdog(call.id, budget: _setupBudget);
    unawaited(IncomingCallRingtone.stop());
    try {
      await _ensureCallPermissions();
      if (operation != _operation) return;
      final session = await _acceptOnServer(call.id);
      if (operation != _operation) {
        if (session?.canControl == true) await _endCancelledServerCall(call.id);
        return;
      }
      if (session == null || !session.canControl) {
        // Call already finished server-side — end quietly, no error banner.
        await _finishLocal(VoiceCallPhase.ended, reason: 'accept.already_over');
        return;
      }
      voiceCallLog('accept.api.ok', callId: call.id, phase: 'connecting');
      _answeringCallId = null;
      // The server now pushes "answered elsewhere" to every device on this
      // account, this one included — FCM cannot address a single device. This
      // durable mark is how the background isolate, which has none of this
      // state, knows the push is about a call it is holding rather than one it
      // is ringing.
      unawaited(CallAnsweredGuard.mark(call.id));
      state = VoiceCallState(
        phase: VoiceCallPhase.connecting,
        call: session.call,
        iceServers: session.iceServers,
        speaker: state.speaker,
        speakerChosen: state.speakerChosen,
        // Only the callee can accept, so the server just named this account.
        currentUserId: callIdentity(
          state.currentUserId,
          session.call.calleeId,
          source: 'accept',
        ),
      );
      // Armed before the engine is prepared, not after: a prepare that never
      // returns (audio session, microphone) used to leave the call on
      // "Connecting…" with no timeout at all.
      _startConnectWatchdog(call.id, budget: _setupBudget);
      // Prefer marking CallKit active over endCall — endCall emits ACTION_CALL_ENDED.
      _suppressCallKitEnded.arm(call.id, source: 'accept.api.ok');
      try {
        await FlutterCallkitIncoming.setCallConnected(call.id);
        voiceCallLog('callkit.setConnected', callId: call.id);
      } catch (_) {}
      voiceCallLog(
        'engine.prepare.begin',
        callId: call.id,
        phase: 'connecting',
      );
      // Callee must be on WS before the caller offer arrives / is flushed.
      await _ws.connect();
      if (operation != _operation) return;
      if (session.call.isVideo) await _ensureCameraPermission();
      if (operation != _operation) return;
      await _prepareEngine(session);
      if (_engine == null || state.call?.id != call.id) {
        voiceCallLog(
          'engine.prepare.abort',
          callId: call.id,
          phase: _phaseName,
          reason: 'engine_null_or_call_changed',
        );
        return;
      }
      await _flushPendingSignals();
    } catch (error) {
      if (operation == _operation) await _failLocal('accept_failed', error);
    } finally {
      if (operation == _operation) _transitioning = false;
    }
  }

  /// Accept on the server, reconciling a state conflict instead of failing.
  ///
  /// Android can deliver Accept more than once (CallKit event, app recovery,
  /// in-app button). A duplicate accept, or one that lands just after the
  /// server already recorded it, must continue into WebRTC — not show an error.
  /// Returns null when the call is already over server-side.
  Future<VoiceCallSession?> _acceptOnServer(String callId) async {
    try {
      return await _repository.action(callId, 'accept');
    } on DioException catch (error) {
      final conflict =
          error.response?.statusCode == 409 ||
          _apiError(error).contains('voice_call_state_conflict');
      if (!conflict) rethrow;

      voiceCallLog(
        'accept.api.conflict',
        callId: callId,
        phase: _phaseName,
        reason: _debugError(error),
      );
      final session = await _repository.get(callId);
      final call = session.call;
      if (session.canControl &&
          call.status == 'accepted' &&
          (state.currentUserId.isEmpty ||
              call.calleeId == state.currentUserId)) {
        voiceCallLog('accept.reconciled', callId: callId, phase: 'connecting');
        return session;
      }
      voiceCallLog(
        'accept.conflict.terminal',
        callId: callId,
        reason: 'status_${call.status}',
      );
      return null;
    }
  }

  Future<void> declineIncoming([String? callId]) async {
    final id = callId ?? state.call?.id;
    if (id == null || id.isEmpty) return;
    // Already leaving the call UI — ignore duplicate Decline taps.
    if (!state.active && callId == null) return;
    // A CallKit decline — from its full-screen UI or from the notification
    // action — usually names a call this provider never loaded, because the
    // push was handled while the app sat in the background. Everything below
    // therefore works from `id`, never from `state.call`: with the state path
    // alone the native record survived the decline, so the ringtone kept its
    // `native` holder and resuming the app recovered the call and rang again.
    _rememberFinished(id);
    // The other half of that rule: a decline for a call that is NOT the one
    // in state owns that call's native surface and its server row, and
    // nothing else. It used to mark whatever was in state as declined and
    // take the state machine, which ended a live call for a decline pressed
    // on a stale notification.
    final current = state.call;
    final ownsState = current != null && current.id == id;
    callTrace(
      'CALL_DECLINE',
      callId: id,
      activeCallId: current?.id,
      engineCallId: _engineCallId,
      previousPhase: _phaseName,
      generation: _operation,
      source: callId == null ? 'in_app' : 'native',
    );
    if (_transitioning) {
      // Some other transition owns the state machine; the native surface still
      // has to go, or the user is left with a ringing screen they declined.
      if (ownsState) {
        await hangUp(source: 'decline.transitioning');
      } else {
        await _endNative(id, source: 'decline.transitioning');
      }
      return;
    }
    voiceCallLog('decline.begin', callId: id, phase: _phaseName);
    if (ownsState) {
      _transitioning = true;
      // End local UI/ringtone first so Decline feels instant (no second tap).
      state = state.copyWith(call: current.copyWith(status: 'declined'));
    }
    await _finishLocal(
      VoiceCallPhase.ended,
      reason: 'decline.local',
      callId: id,
    );
    try {
      await _repository.action(id, 'decline');
    } catch (_) {
      // The server may already have expired the ringing call.
    }
  }

  Future<void> hangUp({String source = 'hangUp'}) async {
    final call = state.call;
    if (call == null) {
      await _finishLocal(VoiceCallPhase.ended, reason: '$source.no_call');
      return;
    }
    if (!state.active) return;
    _transitioning = true;
    final action = switch (state.phase) {
      VoiceCallPhase.outgoingRinging => 'cancel',
      VoiceCallPhase.incomingRinging => 'decline',
      // Answering, but the server has not recorded the accept yet: the call
      // is still ringing there, and `end` would leave the caller hearing it.
      VoiceCallPhase.connecting when _answeringCallId == call.id => 'decline',
      _ => 'end',
    };
    voiceCallLog(
      'hangUp.begin',
      callId: call.id,
      phase: _phaseName,
      source: source,
      reason: action,
    );
    // Tear down UI immediately; lifecycle API can finish in the background.
    await _finishLocal(VoiceCallPhase.ended, reason: '$source.$action');
    try {
      await _repository.action(call.id, action);
    } catch (_) {
      // Local media must stop even if the final lifecycle request times out.
    }
  }

  Future<void> _endCancelledServerCall(String callId) async {
    try {
      await _repository.action(callId, 'end');
    } catch (_) {
      // Server ring expiry / heartbeat expiry remains the outage backstop.
    }
  }

  Future<void> toggleMute() async {
    final next = !state.muted;
    final callId = state.call?.id;
    await _engine?.setMuted(next);
    // The engine call awaits: a mute pressed on one call never lands on the
    // next one's state.
    if (state.call?.id != callId) return;
    state = state.copyWith(muted: next);
    final id = state.call?.id;
    if (id != null) {
      await FlutterCallkitIncoming.muteCall(id, isMuted: next);
    }
  }

  /// Works in every phase. Before the engine exists (ringing) the choice is
  /// only recorded, and `_prepareEngine` opens the media on it; while the
  /// engine is being prepared it goes to that engine, which applies the
  /// newest press when its media is attached.
  Future<void> toggleSpeaker() async {
    final next = !state.speaker;
    state = state.copyWith(speaker: next, speakerChosen: true);
    await (_engine ?? _preparingEngine)?.setSpeaker(next);
  }

  Future<void> toggleCamera() async {
    final engine = _engine;
    if (engine == null || state.phase != VoiceCallPhase.connected) return;
    final callId = state.call?.id;
    try {
      state = state.copyWith(clearCameraError: true);
      if (engine.cameraOn) {
        await engine.stopCamera();
      } else {
        if (!await _ensureCameraPermission()) {
          throw StateError('camera permission denied');
        }
        await engine.startCamera(front: state.cameraFront);
      }
    } catch (error) {
      voiceCallLog(
        'camera.toggle.failed',
        callId: state.call?.id,
        phase: _phaseName,
        reason: _debugError(error),
      );
      if (state.call?.id != callId) return;
      state = state.copyWith(
        cameraError: error.toString().toLowerCase().contains('permission')
            ? 'Camera permission was not granted.'
            : 'Could not start the camera.',
      );
    }
  }

  Future<void> switchCamera() async {
    try {
      await _engine?.switchCamera();
    } catch (error) {
      voiceCallLog('camera.switch.failed', reason: _debugError(error));
    }
  }

  /// Android revokes the camera from a backgrounded app; pausing the track
  /// ourselves keeps the transceiver so the picture resumes on return instead
  /// of needing a renegotiation.
  Future<void> onAppLifecycle(AppLifecycleState lifecycle) async {
    final engine = _engine;
    if (engine == null || !engine.cameraOn) return;
    final paused =
        lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.hidden ||
        lifecycle == AppLifecycleState.detached;
    await engine.setCameraPaused(paused);
  }

  /// The capture was ended from the system (status-bar chip, Cast tile).
  /// Without this the call kept claiming a share: the peer sat on a frozen
  /// frame until the user came back and pressed Stop.
  Future<void> endScreenShareFromSystem() async {
    final engine = _engine;
    if (engine == null || !state.screenSharing) return;
    await engine.stopScreenShare();
  }

  Future<void> toggleScreenShare() async {
    final engine = _engine;
    if (engine == null || state.phase != VoiceCallPhase.connected) return;
    // Pressing Share while the other side is sharing TAKES OVER. It used to
    // return here without a word, so on a call where the desktop shared first
    // the button on the phone did nothing at all and reported nothing —
    // indistinguishable from a broken button. There is one shared screen in a
    // 1:1 call, and this is how it changes hands.
    final takingOver = state.remoteScreenStream != null && !state.screenSharing;
    final callId = state.call?.id;
    try {
      state = state.copyWith(clearScreenShareError: true);
      if (state.screenSharing) {
        await engine.stopScreenShare();
      } else {
        await engine.startScreenShare(takeover: takingOver);
      }
    } catch (error) {
      voiceCallLog(
        'screenShare.failed',
        callId: state.call?.id,
        phase: _phaseName,
        reason: _debugError(error),
      );
      if (state.call?.id != callId) return;
      state = state.copyWith(
        screenShareError: error.toString().toLowerCase().contains('permission')
            ? 'Screen sharing permission was not granted.'
            : 'Could not share this screen.',
      );
    }
  }

  void reset() => _resetIfOwned(state.call?.id, source: 'reset');

  /// Returns to idle once a finished call has had its moment on screen — and
  /// only for that call.
  ///
  /// [owner] is the call the reset was armed for. It used to write idle
  /// unconditionally five seconds after ANY call ended, so a call that
  /// arrived or was answered inside that window was wiped mid-ring or
  /// mid-call: the screen, the return bar and the ongoing notification all
  /// left while the media kept running, with nothing left to hang it up.
  /// Cancelling the timer is not the protection; checking here is.
  void _resetIfOwned(String? owner, {required String source}) {
    _resetTimer?.cancel();
    _resetTimer = null;
    final activeId = state.call?.id;
    final ignored = activeId != owner
        ? 'stale_call'
        : state.active
        ? 'call_active'
        : _engine != null || _preparingEngine != null
        ? 'engine_live'
        : null;
    if (ignored != null) {
      callTrace(
        'RESET_IGNORED',
        callId: owner,
        activeCallId: activeId,
        engineCallId: _engineCallId,
        previousPhase: _phaseName,
        generation: _operation,
        source: source,
        reason: ignored,
      );
      return;
    }
    callTrace(
      'RESET_FIRED',
      callId: owner,
      previousPhase: _phaseName,
      generation: _operation,
      source: source,
    );
    _write(VoiceCallState(currentUserId: state.currentUserId), 'reset');
  }

  void _handleWsEvent(Map<String, dynamic> event) {
    final type = event['type'] as String? ?? '';
    if (!type.startsWith('call.')) return;
    if (type == 'call.signal') {
      final callId = event['call_id'] as String? ?? '';
      if (callId != state.call?.id) return;
      final signal = event['signal'];
      if (signal is! Map) return;
      final parsed = Map<String, dynamic>.from(signal);
      final kind = parsed['kind'] as String? ?? '';
      voiceCallLog(
        'signal.$kind.received',
        callId: callId,
        phase: _phaseName,
        source: 'ws',
      );
      final engine = _engine;
      if (engine == null || !engine.ready) {
        _pendingSignals.add(parsed);
      } else {
        unawaited(_handleLiveSignal(callId, engine, parsed));
      }
      return;
    }

    final rawCall = event['call'];
    if (rawCall is! Map) return;
    final call = VoiceCall.fromJson(Map<String, dynamic>.from(rawCall));
    switch (type) {
      case 'call.incoming':
        unawaited(_onIncoming(call));
      case 'call.ringing':
        _onRemoteRinging(call);
      case 'call.accepted':
        unawaited(_onAccepted(call));
      case 'call.declined':
      case 'call.cancelled':
      case 'call.ended':
      case 'call.failed':
      case 'call.missed':
        // Remember and close terminal calls even if their incoming event has
        // not arrived yet. Otherwise a later stale incoming event resurrects
        // the accept/reject overlay with no future event left to dismiss it.
        _rememberFinished(call.id);
        unawaited(VoiceCallEndedGuard.markEnded(call.id));
        unawaited(AndroidCallUi.endCall(call.id));
        if (state.call?.id == call.id) {
          voiceCallLog(
            'ws.$type',
            callId: call.id,
            phase: _phaseName,
            source: 'ws',
          );
          state = state.copyWith(call: call);
          unawaited(
            _finishLocal(
              type == 'call.failed'
                  ? VoiceCallPhase.failed
                  : VoiceCallPhase.ended,
              reason: 'ws.$type',
            ),
          );
        }
    }
  }

  /// Caller side: a callee device is ringing. The event can beat the start
  /// response that names the call, so an unknown id is remembered for it.
  void _onRemoteRinging(VoiceCall call) {
    final current = state.call;
    if (current == null || current.id != call.id) {
      // Only while this device is placing a call — an idle device of the
      // same account must not accumulate ids.
      if (state.phase == VoiceCallPhase.starting) {
        _remoteRingingCallIds.add(call.id);
      }
      return;
    }
    if (state.phase != VoiceCallPhase.outgoingRinging) return;
    state = state.copyWith(
      call: current.copyWith(
        calleeRingingAt: call.calleeRingingAt ?? DateTime.now(),
      ),
    );
  }

  Future<void> _onIncoming(VoiceCall call) async {
    if (_wasFinished(call.id) || call.isTerminal) {
      await _endNative(call.id, source: 'incoming.finished');
      return;
    }
    if (call.expiresAt.isBefore(DateTime.now())) return;
    if (state.active) return;
    // Media that exists is a call that exists, whatever state says: a phone
    // holding another call's engine is busy, exactly as while `active`.
    if (_holdsLiveCallOtherThan(call.id)) {
      _traceStale('incoming', call.id, reason: 'engine_live');
      return;
    }
    _claimStateFor(call.id, source: 'incoming');
    _write(
      VoiceCallState(
        phase: VoiceCallPhase.incomingRinging,
        call: call,
        // `call.incoming` is only ever sent to the callee.
        currentUserId: state.currentUserId.isEmpty
            ? call.calleeId
            : state.currentUserId,
      ),
      'incoming',
    );
    // Accept may already have been pressed on CallKit: the app was started
    // (or brought forward) BY that press, and this event is the socket or a
    // push replaying the ring. Ringing again here is the "I answered and the
    // app asked me to answer again" report.
    if (await _adoptNativeAccept()) return;
    if (state.call?.id != call.id ||
        state.phase != VoiceCallPhase.incomingRinging) {
      return;
    }
    _startRingTimer(call);
    // This device rings from here on — the Flutter screen or CallKit.
    unawaited(postVoiceCallRingingAck(call.id));
    // Foreground (resumed): CallStoreSync opens Flutter /call.
    // Background / no-focus: native CallKit full-screen is the visible UI.
    await ensureNativeIncomingUi();
  }

  /// Show native full-screen incoming UI when Flutter is not on screen.
  ///
  /// Android blocks starting activities from a backgrounded process unless
  /// CallKit / full-screen intent is used — this is what the callee sees when
  /// AbabilX is minimized or another app has focus.
  Future<void> ensureNativeIncomingUi({bool force = false}) async {
    final call = state.call;
    if (call == null || state.phase != VoiceCallPhase.incomingRinging) return;
    if (call.isTerminal || call.expiresAt.isBefore(DateTime.now())) return;

    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (flutterOwnsRingingUi && !force) {
      // App lifecycle can flip resumed/inactive several times a second while
      // ringing (system dialogs, notification shade, OEM quirks) and each
      // flip re-enters here. Only a native call record actually showing means
      // there is something to hand off from — otherwise this is a redundant
      // re-confirmation, and forcing the handoff dance anyway used to replay
      // the tone from position 0 on every tick, which sounded like the ring
      // stopping every couple of seconds.
      if (!await AndroidCallUi.isShowing(call.id)) {
        await IncomingCallRingtone.start();
        return;
      }
      voiceCallLog(
        'incoming.callkit.skip',
        callId: call.id,
        phase: _phaseName,
        reason: 'flutter_focused',
      );
      // A push may have raised CallKit a moment before Flutter came forward.
      // Take the ringing UI back so the user sees one screen, not a native
      // overlay on top of `/call`. Dismissing it is not a hang-up, so the
      // ENDED echo must be swallowed.
      // Take the in-app hold on the ringer *before* dismissing CallKit: both
      // surfaces share one native player, and releasing its last holder would
      // stop the tone and replay it from the top mid-ring.
      await IncomingCallRingtone.start();
      _suppressCallKitEnded.arm(call.id, source: 'incoming.callkit.hide');
      await AndroidCallUi.hideIncoming(call.id);
      return;
    }

    voiceCallLog(
      'incoming.callkit.show',
      callId: call.id,
      phase: _phaseName,
      source: force ? 'force' : 'background',
      reason: 'lifecycle=${lifecycle?.name ?? 'unknown'}',
    );
    // CallKit brings its own ringer, so the in-app tone hands back rather than
    // playing underneath it — two players fight for focus and one drops out.
    await IncomingCallRingtone.stop();
    await AndroidCallUi.showIncomingFromCall(call);
  }

  Future<void> _onAccepted(VoiceCall call) async {
    if (_wasFinished(call.id)) return;
    if (state.call?.id != call.id) return;
    // Another device answered while this one is still only ringing.
    if (state.phase == VoiceCallPhase.incomingRinging && !_transitioning) {
      voiceCallLog(
        'accepted.other_device',
        callId: call.id,
        phase: _phaseName,
        source: 'ws.call.accepted',
      );
      state = state.copyWith(call: call);
      await _finishLocal(VoiceCallPhase.ended, reason: 'accepted.other_device');
      return;
    }
    if (!state.outgoing || _engine != null || _preparingEngine != null) return;
    final operation = _operation;
    try {
      final ice = state.iceServers.isNotEmpty
          ? state.iceServers
          : (await _repository.get(call.id)).iceServers;
      if (operation != _operation || state.call?.id != call.id) return;
      final session = VoiceCallSession(call: call, iceServers: ice);
      state = state.copyWith(
        phase: VoiceCallPhase.connecting,
        call: call,
        iceServers: ice,
      );
      _ringTimer?.cancel();
      _startConnectWatchdog(call.id, budget: _setupBudget);
      voiceCallLog(
        'engine.prepare.begin',
        callId: call.id,
        phase: 'connecting',
        source: 'caller.onAccepted',
      );
      // Offer/answer must ride the notification WS — wait before negotiating.
      await _ws.connect();
      if (operation != _operation || state.call?.id != call.id) return;
      await _prepareEngine(session);
      if (_engine == null || state.call?.id != call.id) return;
      // Anything the callee sent while prepare() was still running (mic
      // permission / getUserMedia can take seconds) is queued, not dropped.
      await _flushPendingSignals();
      await _engine!.createAndSendOffer();
      voiceCallLog('signal.offer.sent', callId: call.id, phase: _phaseName);
      _scheduleOfferRetry(call.id);
    } catch (error) {
      if (operation == _operation) await _failLocal('offer_failed', error);
    }
  }

  /// If the first offer was lost (WS gap / full buffer), resend once.
  void _scheduleOfferRetry(String callId) {
    _renegotiateTimer?.cancel();
    _offerResent = false;
    _renegotiateTimer = Timer(const Duration(seconds: 6), () {
      if (state.call?.id != callId || _wasFinished(callId)) return;
      if (state.phase != VoiceCallPhase.connecting) return;
      final engine = _engine;
      if (engine == null || !engine.ready || engine.answerReceived) return;
      if (_offerResent) return;
      _offerResent = true;
      voiceCallLog(
        'signal.offer.retry',
        callId: callId,
        phase: _phaseName,
        reason: 'no_answer_yet',
      );
      unawaited(engine.createAndSendOffer(renegotiate: true));
    });
  }

  Future<void> _prepareEngine(VoiceCallSession session) async {
    final call = session.call;
    final callId = call.id;
    // One engine, one call. Building over another call's engine would drop
    // the only reference to it: its microphone and peer connection would run
    // on with nothing left that could close them.
    if ((_engine != null || _preparingEngine != null) &&
        _engineCallId != callId) {
      _traceStale('prepareEngine', callId, reason: 'engine_owned');
      return;
    }
    CallAudioRoute.bindCall(callId);
    final engine = ref.read(voicePeerEngineFactoryProvider)(
      sendSignal: (signal) => _ws.sendWhenConnected({
        'type': 'call.signal',
        'call_id': callId,
        'signal': signal,
      }),
      onConnected: () {
        if (state.call?.id != callId || _wasFinished(callId)) return;
        _ringTimer?.cancel();
        _connectWatchdog?.cancel();
        _renegotiateTimer?.cancel();
        voiceCallLog('ice.state.connected', callId: callId, phase: 'connected');
        state = state.copyWith(
          phase: VoiceCallPhase.connected,
          connectedAt: DateTime.now(),
          clearError: true,
        );
        unawaited(FlutterCallkitIncoming.setCallConnected(callId));
      },
      onFailed: (reason) {
        if (state.call?.id == callId && !_wasFinished(callId)) {
          unawaited(_failLocal(reason));
        }
      },
      onTrouble: (reason, {bool immediate = false}) {
        if (state.call?.id != callId || _wasFinished(callId)) return;
        // Recovery is only meaningful once media has flowed at least once.
        // Before that the connect watchdog owns the timeout, and a restart
        // would race the very first offer/answer.
        if (state.connectedAt == null) {
          unawaited(_failLocal(reason));
          return;
        }
        _reconnect?.noteTrouble(reason, immediate: immediate);
      },
      onHealthy: () {
        if (state.call?.id != callId || _wasFinished(callId)) return;
        _reconnect?.noteHealthy();
      },
      onRestartRequested: () {
        if (state.call?.id != callId || _wasFinished(callId)) return;
        _reconnect?.noteRestartRequested();
      },
      onLocalScreenChanged: (sharing) {
        if (state.call?.id != callId || _wasFinished(callId)) return;
        state = state.copyWith(
          screenSharing: sharing,
          clearScreenShareError: true,
        );
      },
      onRemoteScreenChanged: (stream) {
        if (state.call?.id != callId || _wasFinished(callId)) return;
        state = state.copyWith(
          remoteScreenStream: stream,
          clearRemoteScreen: stream == null,
        );
      },
      onLocalCameraChanged: (stream, {required bool front}) {
        if (state.call?.id != callId || _wasFinished(callId)) return;
        state = state.copyWith(
          localCameraStream: stream,
          clearLocalCamera: stream == null,
          cameraFront: front,
          clearCameraError: true,
        );
      },
      onRemoteCameraChanged: (stream) {
        if (state.call?.id != callId || _wasFinished(callId)) return;
        state = state.copyWith(
          remoteCameraStream: stream,
          clearRemoteCamera: stream == null,
        );
      },
      // The side that placed the call is the only one allowed to offer.
      isOfferer: state.outgoing,
    );
    // Ask for the camera BEFORE the first offer. Checking without asking was
    // why a first-ever video call silently became an audio one: nothing else
    // requests this permission, so the check could only ever fail, and the
    // initial SDP then carried no video at all.
    _preparingEngine = engine;
    _engineCallId = callId;
    callTrace(
      'ENGINE_CREATED',
      callId: callId,
      activeCallId: state.call?.id,
      generation: _operation,
    );
    var disposed = false;
    try {
      final video = call.isVideo && await _ensureCameraPermission();
      if (_wasFinished(callId) || state.call?.id != callId) return;
      await engine.prepare(
        iceServers: session.iceServers,
        video: video,
        speaker: state.speakerChoice,
      );
    } catch (_) {
      // Nothing holds this engine once `_preparingEngine` is cleared below,
      // so a prepare that threw has to be closed here or never.
      disposed = true;
      if (identical(_preparingEngine, engine)) _preparingEngine = null;
      await _disposeEngine(engine, callId, 'prepare.failed');
      rethrow;
    } finally {
      if (identical(_preparingEngine, engine)) _preparingEngine = null;
      if (!disposed && (_wasFinished(callId) || state.call?.id != callId)) {
        disposed = true;
        await _disposeEngine(engine, callId, 'prepare.call_gone');
      }
    }
    // Call may have ended, been replaced, or left connecting while prepare ran.
    if (state.call?.id != callId ||
        (state.phase != VoiceCallPhase.connecting &&
            state.phase != VoiceCallPhase.connected)) {
      voiceCallLog(
        'engine.prepare.discard',
        callId: callId,
        phase: _phaseName,
        reason: 'stale_after_prepare',
      );
      if (!disposed) await _disposeEngine(engine, callId, 'prepare.stale');
      return;
    }
    _engine = engine;
    _heartbeat.start(callId);
    _reconnect = VoiceReconnectController(
      // Only the original caller re-offers; the callee asks it to. Two
      // simultaneous restart offers collide and neither is applied.
      isOfferer: () => state.outgoing,
      restart: () => _restartIce(callId),
      // This call's engine and this call's state, by identity: the controller
      // is disposed during teardown, and until that lands its timers must not
      // reach whichever call came next.
      requestPeerRestart: () async {
        if (identical(_engine, engine)) await engine.requestRestart();
      },
      onGaveUp: (reason) {
        if (state.call?.id != callId || _wasFinished(callId)) return;
        unawaited(_failLocal(reason));
      },
      onReconnectingChanged: (value) {
        if (state.call?.id != callId || _wasFinished(callId)) return;
        state = state.copyWith(
          reconnectingSince: value ? DateTime.now() : null,
          clearReconnectingSince: !value,
        );
      },
    );
    if (state.muted) {
      await engine.setMuted(true);
    }
    // Mirrors the route VoicePeerEngine just applied: a Speaker press made
    // while ringing, else loudspeaker for a call that opened with the camera,
    // earpiece otherwise. Never plain `cameraOn`: that reset a caller who had
    // chosen the loudspeaker back to the earpiece the moment the call was
    // answered.
    state = state.copyWith(speaker: engine.speakerOn);
    voiceCallLog('engine.prepare.ok', callId: callId, phase: _phaseName);
    _startConnectWatchdog(callId);
  }

  /// One recovery attempt: re-issue ICE servers, then offer fresh candidates
  /// over the existing signalling channel.
  Future<void> _restartIce(String callId) async {
    final engine = _engine;
    if (engine == null || !_restartStillWanted(engine, callId)) return;
    // The restart offer rides the notification WS — reconnect it first, since
    // the same outage that killed the media usually dropped the socket too.
    await _ws.connect();
    if (!_restartStillWanted(engine, callId)) return;
    try {
      final session = await _repository.get(callId);
      // Identity, not just the id: the call can end and a new one start on the
      // same notifier while this fetch was in flight, and applying a stale ICE
      // config to a fresh engine is worse than not restarting at all.
      if (!_restartStillWanted(engine, callId)) return;
      // The peer's app can die without ever sending call.ended — the WS event
      // that would normally close this call is simply lost. Without this the
      // recovery would spend its whole budget restarting onto a call the
      // server already considers over.
      if (session.call.isTerminal) {
        voiceCallLog(
          'reconnect.peer_gone',
          callId: callId,
          phase: _phaseName,
          reason: 'status=${session.call.status}',
        );
        state = state.copyWith(
          call: session.call,
          clearReconnectingSince: true,
        );
        await _finishLocal(
          VoiceCallPhase.ended,
          reason: 'reconnect.call_already_${session.call.status}',
        );
        return;
      }
      if (session.iceServers.isNotEmpty) {
        state = state.copyWith(iceServers: session.iceServers);
        await engine.applyIceServers(session.iceServers);
      }
    } catch (error) {
      // Best-effort: coturn credentials are timestamped and a long call can
      // outlive them, but restarting with the old ones still beats not
      // restarting at all.
      voiceCallLog(
        'reconnect.ice.refresh.failed',
        callId: callId,
        phase: _phaseName,
        reason: _debugError(error),
      );
    }
    if (!_restartStillWanted(engine, callId)) return;
    await engine.restartIce();
  }

  /// The engine this restart began on is still the live one for this call.
  bool _restartStillWanted(VoicePeerEngine engine, String callId) =>
      identical(_engine, engine) && state.call?.id == callId;

  /// Never leave a call stuck on "Connecting…" when the peer never negotiates
  /// (lost signalling, no offer, ICE blocked by a restrictive network).
  ///
  /// [budget] is longer while the engine is still being prepared, which can
  /// include a permission dialog; `_prepareEngine` re-arms it with the normal
  /// window once media setup is done.
  void _startConnectWatchdog(
    String callId, {
    Duration budget = const Duration(seconds: 35),
  }) {
    _connectWatchdog?.cancel();
    _connectWatchdog = Timer(budget, () {
      if (state.call?.id != callId || _wasFinished(callId)) return;
      if (state.phase != VoiceCallPhase.connecting) return;
      voiceCallLog(
        'connect.watchdog.timeout',
        callId: callId,
        phase: _phaseName,
      );
      unawaited(_failLocal('connect_timeout'));
    });
  }

  Future<void> _flushPendingSignals() async {
    final engine = _engine;
    if (engine == null) return;
    for (final signal in List<Map<String, dynamic>>.from(_pendingSignals)) {
      await engine.handleSignal(signal);
    }
    _pendingSignals.clear();
  }

  Future<void> _handleLiveSignal(
    String callId,
    VoicePeerEngine engine,
    Map<String, dynamic> signal,
  ) async {
    try {
      await engine.handleSignal(signal);
    } catch (error) {
      if (state.call?.id != callId || !state.active) return;
      voiceCallLog(
        'signal.handle.failed',
        callId: callId,
        phase: _phaseName,
        reason: _debugError(error),
      );
      // One bad SDP must not end a call that is already carrying media. A
      // renegotiation that collides, an answer that arrives twice, a stale
      // description — all of these threw here and killed the call on both
      // sides at once, which is why video dropped far more often than audio:
      // it renegotiates and audio does not. Once connected, hand it to the
      // reconnect controller instead, which restarts ICE and only gives up
      // after its own window.
      if (state.connectedAt != null) {
        _reconnect?.noteTrouble('signal_handle_failed', immediate: false);
        return;
      }
      await _failLocal('signal_handle_failed', error);
    }
  }

  Future<void> _failLocal(String reason, [Object? error]) async {
    final callId = state.call?.id;
    voiceCallLog(
      'failLocal',
      callId: callId,
      phase: _phaseName,
      reason: error == null ? reason : '$reason | ${_debugError(error)}',
    );
    final notifyServer = callId != null && !state.call!.isTerminal;
    state = state.copyWith(
      phase: VoiceCallPhase.failed,
      error: error == null ? _failureLabel(reason) : _friendlyError(error),
    );
    await _finishLocal(
      VoiceCallPhase.failed,
      reason: 'failLocal.$reason',
      preserveError: true,
    );
    if (notifyServer) {
      try {
        await _repository.action(callId, 'fail', reason: reason);
      } catch (_) {}
    }
  }

  Future<void> _finishLocal(
    VoiceCallPhase phase, {
    required String reason,
    bool preserveError = false,
    String? callId,
  }) async {
    // `callId` is passed when the call being finished is not the one in state
    // — a CallKit decline for a call this isolate never loaded. Falling back
    // to state alone skipped the native dismissal entirely.
    //
    // The other half of that rule: such a call owns its native surface and
    // nothing else. The state machine, the timers, the queued signals and the
    // engine belong to the call in state, and a decline or a late heartbeat
    // for X used to take all of them from Y.
    if (callId != null && callId != state.call?.id) {
      await _finishForeign(callId, reason: reason);
      return;
    }
    final id = callId ?? state.call?.id;
    final operation = ++_operation;
    _ending = true;
    _transitioning = false;
    _answeringCallId = null;
    callTrace(
      'CALL_END',
      callId: id,
      previousPhase: _phaseName,
      newPhase: phase.name,
      engineCallId: _engineCallId,
      generation: operation,
      reason: reason,
    );
    _write(
      state.copyWith(phase: phase, clearReconnectingSince: true),
      'finishLocal.$reason',
    );
    // Whatever is still queued was for this call. The next call's engine
    // must never be handed it.
    _pendingSignals.clear();
    VoicePeerEngine? engine;
    VoicePeerEngine? preparing;
    VoiceReconnectController? reconnect;
    final engineOwner = _engineCallId;
    if (id == null || engineOwner == null || engineOwner == id) {
      _heartbeat.stop();
      engine = _engine;
      preparing = _preparingEngine;
      reconnect = _reconnect;
      _engine = null;
      _preparingEngine = null;
      _reconnect = null;
      _engineCallId = null;
    } else {
      // The engine was built for another call; this one's end is not its end.
      _traceStale('finishLocal.$reason', id, reason: 'engine_not_owned');
    }
    _rememberFinished(id);
    voiceCallLog('finishLocal', callId: id, phase: phase.name, reason: reason);
    _ringTimer?.cancel();
    _connectWatchdog?.cancel();
    _renegotiateTimer?.cancel();
    // Each cleanup is independent: a native failure cannot leave the mic
    // alive, and a media failure cannot keep the next call locked out.
    try {
      for (final cleanup in <Future<void> Function()>[
        if (id != null) () => _endNative(id, source: 'finishLocal.$reason'),
        // Only while this call still holds the state: a ring that began for
        // the next call during this teardown is not this call's to silence.
        () async {
          if (state.call?.id == id) await IncomingCallRingtone.stop();
        },
        if (reconnect != null) reconnect.dispose,
        if (preparing != null)
          () => _disposeEngine(preparing!, engineOwner, 'finishLocal.$reason'),
        if (engine != null)
          () => _disposeEngine(engine!, engineOwner, 'finishLocal.$reason'),
      ]) {
        try {
          await cleanup();
        } catch (error) {
          voiceCallLog(
            'finishLocal.cleanup_failed',
            callId: id,
            reason: '$error',
          );
        }
      }
    } finally {
      _ending = false;
    }
    if (operation != _operation) return;
    // The teardown above awaits, and `_onIncoming` does not move
    // `_operation`: a call that arrived meanwhile owns the state now. Stamping
    // this call's terminal phase onto it — and arming its reset — is how a
    // ring that began right after a call ended used to vanish.
    if (state.call?.id != id) {
      _traceStale('finishLocal.tail', id ?? '', reason: reason);
      return;
    }
    _pendingSignals.clear();
    _offerResent = false;
    _write(
      state.copyWith(
        phase: phase,
        clearReconnectingSince: true,
        clearConnectedAt: false,
        clearError: !preserveError,
      ),
      'finishLocal.done',
    );
    _scheduleReset();
  }

  /// A terminal event for a call that is NOT the one in state: a CallKit
  /// decline pressed on a stale notification while another call is live, a
  /// heartbeat reply that lands after the call was replaced.
  ///
  /// It ends that call's native surface, and — only if the engine was built
  /// for that very call — its media. It never touches the state machine, the
  /// timers, the queued signals or `_operation`: those belong to the call in
  /// state, and every async step of that call checks them.
  Future<void> _finishForeign(String id, {required String reason}) async {
    _traceStale(reason, id);
    _rememberFinished(id);
    VoicePeerEngine? engine;
    VoicePeerEngine? preparing;
    VoiceReconnectController? reconnect;
    // Media outlives its state only through a bug. If it is this call's, it
    // ends with it; anyone else's stays exactly as it is.
    if (_engineCallId == id) {
      _heartbeat.stop();
      engine = _engine;
      preparing = _preparingEngine;
      reconnect = _reconnect;
      _engine = null;
      _preparingEngine = null;
      _reconnect = null;
      _engineCallId = null;
    }
    for (final cleanup in <Future<void> Function()>[
      () => _endNative(id, source: 'finishLocal.$reason'),
      // The in-app tone belongs to the call in state; with none, stop it.
      () async {
        if (state.call == null) await IncomingCallRingtone.stop();
      },
      if (reconnect != null) reconnect.dispose,
      if (preparing != null)
        () => _disposeEngine(preparing!, id, 'finishForeign.$reason'),
      if (engine != null)
        () => _disposeEngine(engine!, id, 'finishForeign.$reason'),
    ]) {
      try {
        await cleanup();
      } catch (error) {
        voiceCallLog(
          'finishLocal.cleanup_failed',
          callId: id,
          reason: '$error',
        );
      }
    }
  }

  /// Disposes [engine], built for [callId], and gives up the ownership mark
  /// once no engine is left to own.
  Future<void> _disposeEngine(
    VoicePeerEngine engine,
    String? callId,
    String reason,
  ) async {
    callTrace(
      'ENGINE_DISPOSED',
      callId: callId,
      activeCallId: state.call?.id,
      generation: _operation,
      reason: reason,
    );
    try {
      await engine.dispose();
    } finally {
      if (_engine == null &&
          _preparingEngine == null &&
          _engineCallId == callId) {
        _engineCallId = null;
      }
    }
  }

  Future<void> _endNative(String callId, {required String source}) async {
    voiceCallLog(
      'callkit.dismiss.begin',
      callId: callId,
      phase: _phaseName,
      source: source,
    );
    callTrace(
      'NATIVE_SURFACE_END',
      callId: callId,
      activeCallId: state.call?.id,
      source: source,
    );
    _suppressCallKitEnded.arm(callId, source: 'endNative.$source');
    // AndroidCallUi.endCall, not the plugin directly: it also releases the
    // CallKit ring holder. Declining from the in-app screen dismisses the
    // native UI without any CallKit event being processed here (this very
    // dismissal is what `_suppressCallKitEnded` was just armed to ignore), so
    // ending it raw left the native ringer with nothing to stop it and the
    // tone outlived the call.
    await AndroidCallUi.endCall(callId);
  }

  void _handleNativeEvent(CallEvent? event) {
    if (event == null) return;
    // Shared by both call systems, so this runs before the group filter below.
    unawaited(releaseNativeRingOnCallKitEvent(event));
    // Both call systems share one CallKit event stream. Group calls carry
    // `extra.type = group_call` and belong to GroupCallNotifier — accepting one
    // here would POST a DM action for a call id the DM API has never seen.
    if (_isGroupCallEvent(event)) return;
    switch (event) {
      case CallEventActionCallAccept(:final callKitParams):
        voiceCallLog(
          'callkit.accept',
          callId: callKitParams.id,
          phase: _phaseName,
          source: 'callkit',
        );
        // Plugin / UI cleanup after Accept must not be treated as hang-up.
        _suppressCallKitEnded.arm(callKitParams.id, source: 'callkit.accept');
        unawaited(acceptIncoming(callKitParams.id));
      case CallEventActionCallDecline(:final callKitParams):
        voiceCallLog(
          'callkit.decline',
          callId: callKitParams.id,
          phase: _phaseName,
          source: 'callkit',
        );
        unawaited(declineIncoming(callKitParams.id));
        // The ringing Activity's Message button declines with a reply.
        unawaited(
          sendCallDeclineMessageFromExtra(
            callKitParams.extra,
            myUserId: state.currentUserId,
          ),
        );
      case CallEventActionCallEnded(:final callKitParams):
        final id = callKitParams.id;
        final suppressed = _suppressCallKitEnded.consume(id);
        final alreadyFinished = _wasFinished(id);
        voiceCallLog(
          'callkit.event.ended',
          callId: id,
          phase: _phaseName,
          source: 'callkit',
          suppress: suppressed || alreadyFinished,
        );
        if (suppressed || alreadyFinished) return;
        if (state.call?.id == id && state.active) {
          unawaited(hangUp(source: 'callkit.ended'));
        } else if (id.isNotEmpty) {
          // Native UI dismissed for a call this isolate never loaded. Nothing
          // local to tear down, but the server still has it ringing and the
          // caller would hear tone until the sweeper expires it.
          _rememberFinished(id);
          unawaited(_declineUnknownNative(id));
        }
      case CallEventActionCallTimeout(:final id):
        if (state.call?.id == id) {
          unawaited(
            _finishLocal(VoiceCallPhase.ended, reason: 'callkit.timeout'),
          );
        }
      case CallEventActionCallToggleMute(:final id, :final isMuted):
        if (state.call?.id == id && state.muted != isMuted) {
          unawaited(toggleMute());
        }
      default:
        break;
    }
  }

  /// Declines a call that only exists natively — no local state to finish.
  Future<void> _declineUnknownNative(String callId) async {
    await _endNative(callId, source: 'callkit.ended.unknown');
    try {
      await _repository.action(callId, 'decline');
    } catch (_) {
      // The server's ring sweeper stays the fallback.
    }
  }

  /// FCM is the lifecycle fallback when the notification WebSocket has a gap.
  /// A terminal push must clear both CallKit and Flutter state immediately;
  /// an incoming push is allowed to ring only after an authoritative GET.
  void _handleForegroundCallPush(RemoteMessage message) {
    final data = Map<String, dynamic>.from(message.data);
    final type = data['type']?.toString() ?? '';
    final callId = data['call_id']?.toString() ?? '';
    if (callId.isEmpty) return;

    if (type == 'voice_call_ended') {
      _rememberFinished(callId);
      unawaited(VoiceCallEndedGuard.markEnded(callId));
      unawaited(AndroidCallUi.endCall(callId));
      if (state.call?.id == callId &&
          state.phase != VoiceCallPhase.idle &&
          state.phase != VoiceCallPhase.ended &&
          state.phase != VoiceCallPhase.failed) {
        unawaited(
          _finishLocal(VoiceCallPhase.ended, reason: 'fcm.voice_call_ended'),
        );
      }
      return;
    }
    if (type == 'voice_call_answered') {
      // Another of this account's devices picked up. Deliberately NOT recorded
      // as finished: that mark suppresses a later `incoming`, and an answered
      // call is one that very much still exists.
      final holdsThisCall = state.call?.id == callId;
      switch (decideAnsweredElsewhere(
        answeredHere:
            holdsThisCall &&
            // The accept response decides ownership. A control push may
            // beat that response back to the device that actually won.
            (_transitioning ||
                state.phase == VoiceCallPhase.connecting ||
                state.phase == VoiceCallPhase.connected),
        ringingHere:
            holdsThisCall && state.phase == VoiceCallPhase.incomingRinging,
      )) {
        case AnsweredElsewhereAction.ignore:
          break;
        case AnsweredElsewhereAction.finishRinging:
          unawaited(
            _finishLocal(
              VoiceCallPhase.ended,
              reason: 'fcm.answered_elsewhere',
              callId: callId,
            ),
          );
        case AnsweredElsewhereAction.dismissNative:
          unawaited(AndroidCallUi.endCall(callId));
      }
      return;
    }
    if (type != 'voice_call' || state.active || _wasFinished(callId)) return;
    unawaited(_recoverForegroundIncoming(callId));
  }

  Future<void> _recoverForegroundIncoming(String callId) async {
    // Re-entered by its own retry, by which time the call may have been
    // adopted from the socket, or have ended.
    if (state.active || _wasFinished(callId)) return;
    final VoiceCallSession session;
    try {
      session = await _repository.get(callId);
    } catch (error) {
      await _onLookupFailed(
        callId,
        error,
        source: 'incoming.push',
        retry: () => _recoverForegroundIncoming(callId),
      );
      return;
    }
    _lookupRetry.settle(callId);
    try {
      final call = session.call;
      if (_wasFinished(callId) ||
          call.status != 'ringing' ||
          call.expiresAt.isBefore(DateTime.now())) {
        await AndroidCallUi.endCall(callId);
        return;
      }
      await _onIncoming(call);
    } catch (_) {
      await AndroidCallUi.endCall(callId);
    }
  }

  bool _isGroupCallEvent(CallEvent event) => switch (event) {
    CallEventActionCallAccept(:final callKitParams) ||
    CallEventActionCallDecline(:final callKitParams) ||
    CallEventActionCallEnded(:final callKitParams) ||
    CallEventActionCallIncoming(:final callKitParams) ||
    CallEventActionCallStart(
      :final callKitParams,
    ) => AndroidGroupCallUi.isGroupCall(callKitParams),
    // Timeout/mute carry only an id, so fall back to "not ours" by id.
    CallEventActionCallTimeout(:final id) => state.call?.id != id,
    _ => false,
  };

  Future<void> _recoverNativeCall() async {
    try {
      final active = await FlutterCallkitIncoming.activeCalls();
      if (active.isEmpty || state.active) return;
      // A live group call also shows up here and is not ours to recover.
      final dmCalls = active
          .where((params) => !AndroidGroupCallUi.isGroupCall(params))
          .toList(growable: false);
      if (dmCalls.isEmpty) return;
      final native = dmCalls.first;
      // Media that exists is a call that exists, whatever state says. Adopting
      // its CallKit record as a ring put a ringing screen over live audio and
      // then ended that audio as "not ringing" — with no word to the server,
      // so the other side sat on "Reconnecting…". Neither engine nor state is
      // touched from here.
      if (_engine != null || _preparingEngine != null) {
        _traceStale('recover', native.id, reason: 'engine_live');
        return;
      }
      if (_wasFinished(native.id)) {
        await _endNative(native.id, source: 'recover.finished');
        return;
      }
      VoiceCallSession session;
      try {
        session = await _repository.get(native.id);
      } catch (error) {
        // A persisted native record from an old login/offline call is not
        // enough to reopen UI: recovery requires a live server call. But a
        // request that failed says nothing about the call, and on a phone that
        // has just woken up it is the common case — the surface stays until
        // the server actually answers.
        await _onLookupFailed(
          native.id,
          error,
          source: 'recover',
          retry: _recoverNativeCall,
        );
        return;
      }
      _lookupRetry.settle(native.id);
      // The answer can be late: another call may hold the phone by now.
      if (state.active ||
          _engine != null ||
          _preparingEngine != null ||
          _wasFinished(native.id)) {
        _traceStale('recover', native.id, reason: 'late_lookup');
        return;
      }
      if (session.call.isTerminal) {
        _rememberFinished(native.id);
        await _endNative(native.id, source: 'recover.terminal');
        return;
      }
      _claimStateFor(session.call.id, source: 'recover');
      _write(
        VoiceCallState(
          phase: VoiceCallPhase.incomingRinging,
          call: session.call,
          iceServers: session.iceServers,
          currentUserId: state.currentUserId,
        ),
        'recover',
      );
      if (native.isAccepted) {
        _suppressCallKitEnded.arm(native.id, source: 'recover.accepted');
        await acceptIncoming(native.id);
      } else {
        _startRingTimer(session.call);
      }
    } catch (_) {
      // No recoverable native call.
    }
  }

  /// Re-attach Flutter state when the app returns and CallKit is already ringing.
  Future<void> syncFromNativeIncoming() async {
    // Accept pressed on the CallKit surface while this isolate was in the
    // background. The plugin's event stream does not replay what it emitted
    // then, so the durable record of that press is `isAccepted` on the native
    // call — and `resyncActiveCall` below never looked at it, because a
    // ringing call already counts as `active`. The app therefore came forward
    // still in `incomingRinging`, took the ringing UI back off CallKit
    // (`ensureNativeIncomingUi`), and asked for a second Accept.
    if (state.phase == VoiceCallPhase.incomingRinging &&
        await _adoptNativeAccept()) {
      return;
    }
    if (state.active) {
      await resyncActiveCall();
      return;
    }
    await _recoverNativeCall();
  }

  /// Applies an Accept that CallKit already recorded for the call in state.
  ///
  /// Returns true when the accept was adopted — including when another accept
  /// is already in flight, since the point of the return value is "do not put
  /// the ringing UI back up", not "the call is connected".
  Future<bool> _adoptNativeAccept() async {
    final call = state.call;
    if (call == null) return false;
    try {
      final active = await FlutterCallkitIncoming.activeCalls();
      final accepted = nativeCallWasAccepted(
        call.id,
        active.map<NativeCallSnapshot>(
          (native) => NativeCallSnapshot(
            id: native.id,
            isAccepted: native.isAccepted == true,
          ),
        ),
      );
      if (!accepted) return false;
    } catch (_) {
      return false;
    }
    voiceCallLog(
      'accept.adopt_native',
      callId: call.id,
      phase: _phaseName,
      source: 'callkit',
    );
    // Same reason as the live `callkit.accept` path: the plugin's own UI
    // teardown after Accept arrives as ENDED and is not a hang-up.
    _suppressCallKitEnded.arm(call.id, source: 'accept.adopt_native');
    await acceptIncoming(call.id);
    return true;
  }

  /// Reconcile with the server after a WS gap or app resume.
  ///
  /// Events delivered while the socket was down are lost, so an active call can
  /// hold a stale phase: a caller stuck on "Calling…" for a call the peer
  /// already accepted, or a live screen for a call that ended.
  Future<void> resyncActiveCall() async {
    final current = state.call;
    if (current == null || !state.active) return;
    if (_transitioning) return;

    VoiceCallSession session;
    try {
      session = await _repository.get(current.id);
    } catch (_) {
      return;
    }
    final call = session.call;
    if (state.call?.id != call.id || !state.active) return;

    voiceCallLog(
      'resync',
      callId: call.id,
      phase: _phaseName,
      reason: 'server_status=${call.status}',
    );

    if (call.isTerminal || !session.canControl) {
      state = state.copyWith(call: call);
      await _finishLocal(VoiceCallPhase.ended, reason: 'resync.terminal');
      return;
    }
    // Caller missed the accepted event — start negotiating now.
    if (call.status == 'accepted' &&
        state.phase == VoiceCallPhase.outgoingRinging) {
      state = state.copyWith(iceServers: session.iceServers);
      await _onAccepted(call);
    }
  }

  void _startRingTimer(VoiceCall call) {
    _ringTimer?.cancel();
    final callId = call.id;
    final remaining = call.expiresAt.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      unawaited(_onRingTimeout(callId));
      return;
    }
    _ringTimer = Timer(remaining + const Duration(seconds: 1), () {
      unawaited(_onRingTimeout(callId));
    });
  }

  /// Ring expiry: caller cancels; callee only stops local UI so the server
  /// sweeper can mark the call `missed` (no client `missed`/`timeout` action).
  Future<void> _onRingTimeout(String callId) async {
    final call = state.call;
    if (call == null || call.id != callId) return;
    if (call.isTerminal) return;
    if (_transitioning) {
      voiceCallLog(
        'ring.timeout.skip',
        callId: callId,
        phase: _phaseName,
        reason: 'transitioning',
      );
      return;
    }
    final phase = state.phase;
    if (phase != VoiceCallPhase.outgoingRinging &&
        phase != VoiceCallPhase.incomingRinging) {
      return;
    }

    if (phase == VoiceCallPhase.outgoingRinging) {
      try {
        await _repository.action(callId, 'cancel');
      } catch (_) {
        // Sweeper / peer may already have finished the ringing call.
      }
      if (state.call?.id != callId ||
          state.phase != VoiceCallPhase.outgoingRinging) {
        return;
      }
      await _finishLocal(VoiceCallPhase.ended, reason: 'ring.timeout.cancel');
      return;
    }

    // Incoming timeout: do not decline — user did not explicitly reject.
    await _finishLocal(VoiceCallPhase.ended, reason: 'ring.timeout.incoming');
  }

  /// Arms the return to idle for the call that just finished. The timer
  /// carries that call's id and [_resetIfOwned] checks it when it fires.
  void _scheduleReset() {
    _resetTimer?.cancel();
    final owner = state.call?.id;
    callTrace(
      'RESET_SCHEDULED',
      callId: owner,
      previousPhase: _phaseName,
      generation: _operation,
    );
    _resetTimer = Timer(
      resetDelay,
      () => _resetIfOwned(owner, source: 'timer'),
    );
  }

  void _cancelReset(String reason, {String? callId}) {
    final timer = _resetTimer;
    if (timer == null || !timer.isActive) return;
    timer.cancel();
    _resetTimer = null;
    callTrace(
      'RESET_CANCELLED',
      callId: callId,
      activeCallId: state.call?.id,
      generation: _operation,
      reason: reason,
    );
  }

  /// A call lookup failed. Only an answer about the CALL may take its
  /// surface down; a request that never got one keeps it and asks again.
  Future<void> _onLookupFailed(
    String callId,
    Object error, {
    required String source,
    required Future<void> Function() retry,
    int? retries,
  }) async {
    final failure = classifyCallLookupFailure(error);
    voiceCallLog(
      '$source.lookup_failed',
      callId: callId,
      phase: _phaseName,
      reason: '${failure.name} | ${_debugError(error)}',
    );
    switch (failure) {
      case CallLookupFailure.gone:
        _rememberFinished(callId);
        await _endNative(callId, source: '$source.gone');
      case CallLookupFailure.rejected:
        await _endNative(callId, source: '$source.rejected');
      case CallLookupFailure.transient:
      case CallLookupFailure.conflict:
        // Bounded: past the budget the surface simply stays. Its own timeout,
        // the next resume and the socket's replay still own it from there.
        _lookupRetry.schedule(callId, () => unawaited(retry()), limit: retries);
      case CallLookupFailure.malformed:
        // One more read. A body that will not parse twice is not going to,
        // and a surface nothing can describe is worse than none.
        final again = _lookupRetry.schedule(
          callId,
          () => unawaited(retry()),
          limit: 1,
        );
        if (!again) await _endNative(callId, source: '$source.malformed');
    }
  }

  /// A terminal lifecycle event can race a replayed WS event or a persisted
  /// CallKit record. Remember locally finished IDs so neither can resurrect a
  /// call screen after the user has already left it.
  void _rememberFinished(String? callId) {
    if (callId == null || callId.isEmpty) return;
    _finishedCallIds
      ..remove(callId)
      ..add(callId);
    while (_finishedCallIds.length > 64) {
      _finishedCallIds.remove(_finishedCallIds.first);
    }
  }

  /// Places the call, and if the server says this account is already busy,
  /// clears the account's own dead call once and tries again.
  ///
  /// The dead call is the whole reason this exists: a drop that took the
  /// network with it never reached the server, so the row stayed live and
  /// every later call was refused. Both people then saw "the other one is in
  /// another call" and neither could do anything about it, because neither
  /// device still knew the id to hang up.
  Future<VoiceCallSession> _startWithStaleRecovery(
    String conversationId,
    bool video,
  ) async {
    try {
      return await _repository.start(conversationId, video: video);
    } on DioException catch (error) {
      final busySelf = _apiError(error).contains('voice_call_busy_self');
      if (!busySelf || !await _clearOwnStaleCall()) rethrow;
      return _repository.start(conversationId, video: video);
    }
  }

  /// Ends a call the server still believes this account is on while nothing on
  /// this device is running one. Never touches a live call: an engine here
  /// means the media session is real and the server is right.
  Future<bool> _clearOwnStaleCall() async {
    if (_engine != null) return false;
    try {
      final stale = await _repository.activeCall();
      if (stale == null) return false;
      voiceCallLog(
        'busy.stale.clear',
        callId: stale.call.id,
        reason: stale.call.status,
      );
      await _repository.action(
        stale.call.id,
        'fail',
        reason: 'stale_call_recovered',
      );
      return true;
    } catch (error) {
      voiceCallLog('busy.stale.clear.failed', reason: _debugError(error));
      return false;
    }
  }

  bool _wasFinished(String callId) => _finishedCallIds.contains(callId);

  Future<void> _ensureCallPermissions() => CallPermissions.ensureMicrophone(
    callId: state.call?.id,
    phase: _phaseName,
  );

  /// Camera is optional on a video call: a refusal degrades to audio rather
  /// than failing the call, so this only throws when asked from a toggle.
  Future<bool> _ensureCameraPermission() =>
      CallPermissions.ensureCamera(callId: state.call?.id);

  /// Ask for microphone up-front so an incoming call can be answered instantly,
  /// including from the lock screen where a dialog cannot be shown.
  Future<void> prewarmCallPermissions() => CallPermissions.prewarm();

  Future<void> _resetResources() async {
    _remoteRingingCallIds.clear();
    _heartbeat.stop();
    _ringTimer?.cancel();
    _resetTimer?.cancel();
    _connectWatchdog?.cancel();
    _renegotiateTimer?.cancel();
    _lookupRetry.cancel();
    final owner = _engineCallId;
    await _reconnect?.dispose();
    _reconnect = null;
    final preparing = _preparingEngine;
    _preparingEngine = null;
    if (preparing != null) {
      await _disposeEngine(preparing, owner, 'resetResources');
    }
    final engine = _engine;
    _engine = null;
    if (engine != null) await _disposeEngine(engine, owner, 'resetResources');
    _engineCallId = null;
    _pendingSignals.clear();
    _offerResent = false;
  }

  String _friendlyError(Object error) {
    final apiError = _apiError(error);
    final value = '$apiError ${error.toString()}';
    if (value.contains('voice_call_busy_self')) {
      return 'You are already in another call.';
    }
    if (value.contains('voice_call_busy')) {
      final name = state.pendingPeerName?.trim();
      if (name != null && name.isNotEmpty) {
        return '$name is in another call';
      }
      return 'This person is in another call';
    }
    if (value.contains('voice_call_peer_unavailable')) {
      return 'This person is unavailable.';
    }
    if (value.contains('voice_call_ice_not_configured')) {
      return 'Calling is not configured on the server yet.';
    }
    if (value.contains('invalid_e2ee_public_key')) {
      return 'The calling server needs to be updated.';
    }
    if (error is DioException && error.response?.statusCode == 404) {
      return 'Calling is not available on the server yet.';
    }
    if (error is DioException && error.response?.statusCode == 429) {
      return 'Too many call attempts. Please wait a moment.';
    }
    if (value.contains('voice_call_state_conflict')) {
      return 'This call already ended.';
    }
    if (value.contains('voice_call_not_found')) {
      return 'This call is no longer available.';
    }
    if (value.toLowerCase().contains('permission')) {
      return 'Microphone permission is required for calls.';
    }
    if (error is DioException &&
        (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.connectionError)) {
      return 'Network problem. Check your connection.';
    }
    return 'Could not start the call.';
  }

  String _apiError(Object error) {
    if (error is! DioException) return '';
    final data = error.response?.data;
    if (data is Map) return data['error']?.toString() ?? '';
    return data?.toString() ?? '';
  }

  String _debugError(Object error) {
    if (error is! DioException) return error.toString();
    return 'status=${error.response?.statusCode} '
        'api_error=${_apiError(error)} type=${error.type}';
  }

  String _failureLabel(String reason) {
    return switch (reason) {
      'signaling_unavailable' => 'The realtime connection was lost.',
      'ice_no_relay' =>
        'Calls only work on the same network right now. '
            'The call relay server is unreachable.',
      'connect_timeout' => 'Could not connect. Check your network.',
      'peer_connection_failed' ||
      'peer_connection_disconnected' => 'The call connection dropped.',
      _ => 'The call could not connect.',
    };
  }

  Future<void> dispose() async {
    await shutdown();
  }
}

final voiceCallProvider = NotifierProvider<VoiceCallNotifier, VoiceCallState>(
  VoiceCallNotifier.new,
);
