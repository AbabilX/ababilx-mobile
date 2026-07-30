import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/network/ws_client.dart';
import '../../messages/data/models/chat_conversation.dart';
import '../../profile/providers/profile_provider.dart';
import '../callkit_ended_suppress.dart';
import '../data/models/voice_call.dart';
import '../data/models/voice_call_session.dart';
import '../data/voice_call_repository.dart';
import '../incoming_call_ringtone.dart';
import '../native/android_call_ui.dart';
import '../voice_call_log.dart';
import '../webrtc/voice_peer_engine.dart';
import 'voice_call_state.dart';

export 'voice_call_state.dart';

class VoiceCallNotifier extends Notifier<VoiceCallState> {
  StreamSubscription<Map<String, dynamic>>? _wsSub;
  StreamSubscription<void>? _wsReconnectSub;
  StreamSubscription<CallEvent?>? _nativeSub;
  VoicePeerEngine? _engine;
  final List<Map<String, dynamic>> _pendingSignals = [];
  Timer? _ringTimer;
  Timer? _resetTimer;
  Timer? _connectWatchdog;
  Timer? _renegotiateTimer;
  bool _booted = false;
  bool _transitioning = false;
  bool _offerResent = false;
  final CallKitEndedSuppress _suppressCallKitEnded = CallKitEndedSuppress();

  VoiceCallRepository get _repository => ref.read(voiceCallRepositoryProvider);
  WsClient get _ws => ref.read(wsClientProvider);

  String get _phaseName => state.phase.name;

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
    return VoiceCallState(currentUserId: userId);
  }

  Future<void> bootstrap() async {
    if (_booted) return;
    _booted = true;
    _wsSub = _ws.events.listen(_handleWsEvent);
    _wsReconnectSub = _ws.reconnects.listen((_) {
      unawaited(resyncActiveCall());
    });
    _nativeSub = FlutterCallkitIncoming.onEvent.listen(_handleNativeEvent);
    await _ws.connect();
    unawaited(prewarmCallPermissions());
    await _recoverNativeCall();
  }

  Future<void> shutdown() async {
    if (!_booted) return;
    _booted = false;
    _ringTimer?.cancel();
    _resetTimer?.cancel();
    _connectWatchdog?.cancel();
    _renegotiateTimer?.cancel();
    await _wsSub?.cancel();
    await _wsReconnectSub?.cancel();
    await _nativeSub?.cancel();
    _wsSub = null;
    _wsReconnectSub = null;
    _nativeSub = null;
    final callId = state.call?.id;
    final currentUserId = state.currentUserId;
    await _resetResources();
    if (callId != null) await _endNative(callId, source: 'shutdown');
    _suppressCallKitEnded.clear();
    state = VoiceCallState(currentUserId: currentUserId);
  }

  Future<void> startOutgoing(ChatConversation conversation) async {
    if (state.active || _transitioning || !conversation.isDm) return;
    if (conversation.peerLeft || conversation.peerUserId == null) {
      state = state.copyWith(
        phase: VoiceCallPhase.failed,
        error: 'This teammate is no longer available.',
      );
      return;
    }
    _transitioning = true;
    try {
      await _resetResources();
      state = VoiceCallState(
        phase: VoiceCallPhase.starting,
        currentUserId: state.currentUserId,
        pendingConversationId: conversation.id,
        pendingPeerName: conversation.peerUserName,
        pendingPeerAvatar: conversation.peerUserAvatar,
      );
      voiceCallLog(
        'start.permission',
        phase: _phaseName,
        source: 'startOutgoing',
      );
      await _ensureCallPermissions();
      voiceCallLog('start.api.begin', source: 'startOutgoing');
      final session = await _repository.start(conversation.id);
      voiceCallLog(
        'start.api.ok',
        callId: session.call.id,
        phase: 'outgoingRinging',
      );
      state = VoiceCallState(
        phase: VoiceCallPhase.outgoingRinging,
        call: session.call,
        iceServers: session.iceServers,
        currentUserId: state.currentUserId,
      );
      await AndroidCallUi.startOutgoing(session.call, state.currentUserId);
      _startRingTimer(session.call);
    } catch (error) {
      voiceCallLog(
        'start.failed',
        reason: _debugError(error),
        source: 'startOutgoing',
      );
      await _resetResources();
      state = state.copyWith(
        phase: VoiceCallPhase.failed,
        error: _friendlyError(error),
      );
      _scheduleReset();
    } finally {
      _transitioning = false;
    }
  }

  Future<void> acceptIncoming([String? callId]) async {
    if (_transitioning) {
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
    if (call == null || (callId != null && call.id != callId)) {
      if (callId == null || callId.isEmpty) return;
      try {
        final session = await _repository.get(callId);
        call = session.call;
        state = VoiceCallState(
          phase: VoiceCallPhase.incomingRinging,
          call: call,
          iceServers: session.iceServers,
          currentUserId: state.currentUserId,
        );
      } catch (_) {
        await _endNative(callId, source: 'accept.get_failed');
        return;
      }
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
      await _endNative(call.id, source: 'accept.not_ringing');
      return;
    }

    _transitioning = true;
    voiceCallLog(
      'accept.begin',
      callId: call.id,
      phase: _phaseName,
      source: 'acceptIncoming',
    );
    try {
      await _ensureCallPermissions();
      final session = await _acceptOnServer(call.id);
      if (session == null) {
        // Call already finished server-side — end quietly, no error banner.
        await _finishLocal(VoiceCallPhase.ended, reason: 'accept.already_over');
        return;
      }
      voiceCallLog('accept.api.ok', callId: call.id, phase: 'connecting');
      state = VoiceCallState(
        phase: VoiceCallPhase.connecting,
        call: session.call,
        iceServers: session.iceServers,
        currentUserId: state.currentUserId,
      );
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
      await _failLocal('accept_failed', error);
    } finally {
      _transitioning = false;
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
      if (call.status == 'accepted' && call.calleeId == state.currentUserId) {
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
    voiceCallLog('decline.begin', callId: id, phase: _phaseName);
    try {
      await _repository.action(id, 'decline');
    } catch (_) {
      // The server may already have expired the ringing call.
    }
    await _finishLocal(VoiceCallPhase.ended, reason: 'decline.local');
  }

  Future<void> hangUp({String source = 'hangUp'}) async {
    final call = state.call;
    if (call == null) {
      await _finishLocal(VoiceCallPhase.ended, reason: '$source.no_call');
      return;
    }
    final action = switch (state.phase) {
      VoiceCallPhase.outgoingRinging => 'cancel',
      VoiceCallPhase.incomingRinging => 'decline',
      _ => 'end',
    };
    voiceCallLog(
      'hangUp.begin',
      callId: call.id,
      phase: _phaseName,
      source: source,
      reason: action,
    );
    try {
      await _repository.action(call.id, action);
    } catch (_) {
      // Local media must stop even if the final lifecycle request times out.
    }
    await _finishLocal(VoiceCallPhase.ended, reason: '$source.$action');
  }

  Future<void> toggleMute() async {
    final next = !state.muted;
    await _engine?.setMuted(next);
    state = state.copyWith(muted: next);
    final id = state.call?.id;
    if (id != null) {
      await FlutterCallkitIncoming.muteCall(id, isMuted: next);
    }
  }

  Future<void> toggleSpeaker() async {
    final next = !state.speaker;
    await _engine?.setSpeaker(next);
    state = state.copyWith(speaker: next);
  }

  void reset() {
    _resetTimer?.cancel();
    state = VoiceCallState(currentUserId: state.currentUserId);
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
        unawaited(engine.handleSignal(parsed));
      }
      return;
    }

    final rawCall = event['call'];
    if (rawCall is! Map) return;
    final call = VoiceCall.fromJson(Map<String, dynamic>.from(rawCall));
    switch (type) {
      case 'call.incoming':
        unawaited(_onIncoming(call));
      case 'call.accepted':
        unawaited(_onAccepted(call));
      case 'call.declined':
      case 'call.cancelled':
      case 'call.ended':
      case 'call.failed':
      case 'call.missed':
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

  Future<void> _onIncoming(VoiceCall call) async {
    if (call.expiresAt.isBefore(DateTime.now())) return;
    if (state.active) return;
    state = VoiceCallState(
      phase: VoiceCallPhase.incomingRinging,
      call: call,
      currentUserId: state.currentUserId,
    );
    _startRingTimer(call);
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
    final flutterFocused = lifecycle == AppLifecycleState.resumed;
    if (flutterFocused && !force) {
      voiceCallLog(
        'incoming.callkit.skip',
        callId: call.id,
        phase: _phaseName,
        reason: 'flutter_focused',
      );
      return;
    }

    voiceCallLog(
      'incoming.callkit.show',
      callId: call.id,
      phase: _phaseName,
      source: force ? 'force' : 'background',
      reason: 'lifecycle=${lifecycle?.name ?? 'unknown'}',
    );
    await AndroidCallUi.showIncomingFromCall(call);
  }

  Future<void> _onAccepted(VoiceCall call) async {
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
    if (!state.outgoing || _engine != null) return;
    try {
      final ice = state.iceServers.isNotEmpty
          ? state.iceServers
          : (await _repository.get(call.id)).iceServers;
      final session = VoiceCallSession(call: call, iceServers: ice);
      state = state.copyWith(
        phase: VoiceCallPhase.connecting,
        call: call,
        iceServers: ice,
      );
      _ringTimer?.cancel();
      voiceCallLog(
        'engine.prepare.begin',
        callId: call.id,
        phase: 'connecting',
        source: 'caller.onAccepted',
      );
      // Offer/answer must ride the notification WS — wait before negotiating.
      await _ws.connect();
      await _prepareEngine(session);
      if (_engine == null || state.call?.id != call.id) return;
      await _engine!.createAndSendOffer();
      voiceCallLog('signal.offer.sent', callId: call.id, phase: _phaseName);
      _scheduleOfferRetry(call.id);
    } catch (error) {
      await _failLocal('offer_failed', error);
    }
  }

  /// If the first offer was lost (WS gap / full buffer), resend once.
  void _scheduleOfferRetry(String callId) {
    _renegotiateTimer?.cancel();
    _offerResent = false;
    _renegotiateTimer = Timer(const Duration(seconds: 6), () {
      if (state.call?.id != callId) return;
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
    final engine = VoicePeerEngine(
      sendSignal: (signal) => _ws.sendWhenConnected({
        'type': 'call.signal',
        'call_id': callId,
        'signal': signal,
      }),
      onConnected: () {
        if (state.call?.id != callId) return;
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
      onFailed: (reason) => unawaited(_failLocal(reason)),
    );
    await engine.prepare(iceServers: session.iceServers);
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
      await engine.dispose();
      return;
    }
    _engine = engine;
    if (state.muted) {
      await engine.setMuted(true);
    }
    // VoicePeerEngine starts Android calls on speaker for an audible default.
    state = state.copyWith(speaker: true);
    voiceCallLog('engine.prepare.ok', callId: callId, phase: _phaseName);
    _startConnectWatchdog(callId);
  }

  /// Never leave a call stuck on "Connecting…" when the peer never negotiates
  /// (lost signalling, no offer, ICE blocked by a restrictive network).
  void _startConnectWatchdog(String callId) {
    _connectWatchdog?.cancel();
    _connectWatchdog = Timer(const Duration(seconds: 35), () {
      if (state.call?.id != callId) return;
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

  Future<void> _failLocal(String reason, [Object? error]) async {
    final callId = state.call?.id;
    voiceCallLog(
      'failLocal',
      callId: callId,
      phase: _phaseName,
      reason: error == null ? reason : '$reason | ${_debugError(error)}',
    );
    if (callId != null && !state.call!.isTerminal) {
      try {
        await _repository.action(callId, 'fail', reason: reason);
      } catch (_) {}
    }
    state = state.copyWith(
      phase: VoiceCallPhase.failed,
      error: error == null ? _failureLabel(reason) : _friendlyError(error),
    );
    await _finishLocal(
      VoiceCallPhase.failed,
      reason: 'failLocal.$reason',
      preserveError: true,
    );
  }

  Future<void> _finishLocal(
    VoiceCallPhase phase, {
    required String reason,
    bool preserveError = false,
  }) async {
    final callId = state.call?.id;
    voiceCallLog(
      'finishLocal',
      callId: callId,
      phase: phase.name,
      reason: reason,
    );
    _ringTimer?.cancel();
    _connectWatchdog?.cancel();
    _renegotiateTimer?.cancel();
    await IncomingCallRingtone.stop();
    await _engine?.dispose();
    _engine = null;
    _pendingSignals.clear();
    _offerResent = false;
    if (callId != null) {
      await _endNative(callId, source: 'finishLocal.$reason');
    }
    state = state.copyWith(
      phase: phase,
      clearConnectedAt: false,
      clearError: !preserveError,
    );
    _scheduleReset();
  }

  Future<void> _endNative(String callId, {required String source}) async {
    voiceCallLog(
      'callkit.dismiss.begin',
      callId: callId,
      phase: _phaseName,
      source: source,
    );
    _suppressCallKitEnded.arm(callId, source: 'endNative.$source');
    try {
      await FlutterCallkitIncoming.endCall(callId);
    } catch (_) {}
  }

  void _handleNativeEvent(CallEvent? event) {
    if (event == null) return;
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
      case CallEventActionCallEnded(:final callKitParams):
        final id = callKitParams.id;
        final suppressed = _suppressCallKitEnded.consume(id);
        voiceCallLog(
          'callkit.event.ended',
          callId: id,
          phase: _phaseName,
          source: 'callkit',
          suppress: suppressed,
        );
        if (suppressed) return;
        if (state.call?.id == id && state.active) {
          unawaited(hangUp(source: 'callkit.ended'));
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

  Future<void> _recoverNativeCall() async {
    try {
      final active = await FlutterCallkitIncoming.activeCalls();
      if (active.isEmpty || state.active) return;
      final native = active.first;
      final session = await _repository.get(native.id);
      if (session.call.isTerminal) {
        await _endNative(native.id, source: 'recover.terminal');
        return;
      }
      state = VoiceCallState(
        phase: VoiceCallPhase.incomingRinging,
        call: session.call,
        iceServers: session.iceServers,
        currentUserId: state.currentUserId,
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
    if (state.active) {
      await resyncActiveCall();
      return;
    }
    await _recoverNativeCall();
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

    if (call.isTerminal) {
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

  void _scheduleReset() {
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 5), reset);
  }

  /// Microphone must be granted before WebRTC capture.
  ///
  /// Requesting needs a foreground Activity; a CallKit accept from the lock
  /// screen would otherwise stall. Already-granted is checked first so the
  /// common path never touches the permission dialog.
  Future<void> _ensureCallPermissions() async {
    if (await Permission.microphone.isGranted) return;

    final resumed =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (!resumed) {
      voiceCallLog(
        'permission.mic.blocked',
        callId: state.call?.id,
        phase: _phaseName,
        reason: 'not_granted_and_app_not_resumed',
      );
      throw StateError('microphone permission denied');
    }

    final microphone = await Permission.microphone.request();
    voiceCallLog(
      'permission.mic',
      callId: state.call?.id,
      reason: microphone.name,
    );
    if (!microphone.isGranted) {
      throw StateError('microphone permission denied');
    }
    // Bluetooth is optional; a denied request falls back to earpiece/speaker.
    await Permission.bluetoothConnect.request();
  }

  /// Ask for microphone up-front so an incoming call can be answered instantly,
  /// including from the lock screen where a dialog cannot be shown.
  Future<void> prewarmCallPermissions() async {
    try {
      if (await Permission.microphone.isGranted) return;
      final status = await Permission.microphone.request();
      voiceCallLog('permission.mic.prewarm', reason: status.name);
    } catch (_) {
      // Non-fatal: accept-time request remains the fallback.
    }
  }

  Future<void> _resetResources() async {
    _ringTimer?.cancel();
    _resetTimer?.cancel();
    _connectWatchdog?.cancel();
    _renegotiateTimer?.cancel();
    await _engine?.dispose();
    _engine = null;
    _pendingSignals.clear();
    _offerResent = false;
  }

  String _friendlyError(Object error) {
    final apiError = _apiError(error);
    final value = '$apiError ${error.toString()}';
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
