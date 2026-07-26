import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/network/ws_client.dart';
import '../../messages/data/models/chat_conversation.dart';
import '../../profile/providers/profile_provider.dart';
import '../data/models/voice_call.dart';
import '../data/models/voice_call_session.dart';
import '../data/voice_call_repository.dart';
import '../native/android_call_ui.dart';
import '../webrtc/voice_peer_engine.dart';
import 'voice_call_state.dart';

export 'voice_call_state.dart';

class VoiceCallNotifier extends Notifier<VoiceCallState> {
  StreamSubscription<Map<String, dynamic>>? _wsSub;
  StreamSubscription<CallEvent?>? _nativeSub;
  VoicePeerEngine? _engine;
  final List<Map<String, dynamic>> _pendingSignals = [];
  Timer? _ringTimer;
  Timer? _resetTimer;
  bool _booted = false;
  bool _transitioning = false;
  bool _suppressNativeEnd = false;

  VoiceCallRepository get _repository => ref.read(voiceCallRepositoryProvider);
  WsClient get _ws => ref.read(wsClientProvider);

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
    _nativeSub = FlutterCallkitIncoming.onEvent.listen(_handleNativeEvent);
    await _ws.connect();
    await _recoverNativeCall();
  }

  Future<void> shutdown() async {
    if (!_booted) return;
    _booted = false;
    _ringTimer?.cancel();
    _resetTimer?.cancel();
    await _wsSub?.cancel();
    await _nativeSub?.cancel();
    _wsSub = null;
    _nativeSub = null;
    final callId = state.call?.id;
    final currentUserId = state.currentUserId;
    await _resetResources();
    if (callId != null) await _endNative(callId);
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
      debugPrint('[call] start.permission | conversation=${conversation.id}');
      await _ensureCallPermissions();
      debugPrint('[call] start.api.begin | conversation=${conversation.id}');
      final session = await _repository.start(conversation.id);
      debugPrint('[call] start.api.ok | call=${session.call.id}');
      state = VoiceCallState(
        phase: VoiceCallPhase.outgoingRinging,
        call: session.call,
        iceServers: session.iceServers,
        currentUserId: state.currentUserId,
      );
      await AndroidCallUi.startOutgoing(session.call, state.currentUserId);
      _startRingTimer(session.call);
    } catch (error) {
      debugPrint('[call] start.failed | ${_debugError(error)}');
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
    if (_transitioning) return;
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
        await _endNative(callId);
        return;
      }
    }
    if (call.status != 'ringing' || call.expiresAt.isBefore(DateTime.now())) {
      await _endNative(call.id);
      return;
    }

    _transitioning = true;
    try {
      await _ensureCallPermissions();
      final session = await _repository.action(call.id, 'accept');
      state = VoiceCallState(
        phase: VoiceCallPhase.connecting,
        call: session.call,
        iceServers: session.iceServers,
        currentUserId: state.currentUserId,
      );
      _ringTimer?.cancel();
      await _prepareEngine(session);
      await _flushPendingSignals();
    } catch (error) {
      await _failLocal('accept_failed', error);
    } finally {
      _transitioning = false;
    }
  }

  Future<void> declineIncoming([String? callId]) async {
    final id = callId ?? state.call?.id;
    if (id == null || id.isEmpty) return;
    try {
      await _repository.action(id, 'decline');
    } catch (_) {
      // The server may already have expired the ringing call.
    }
    await _finishLocal(VoiceCallPhase.ended);
  }

  Future<void> hangUp() async {
    final call = state.call;
    if (call == null) {
      await _finishLocal(VoiceCallPhase.ended);
      return;
    }
    final action = switch (state.phase) {
      VoiceCallPhase.outgoingRinging => 'cancel',
      VoiceCallPhase.incomingRinging => 'decline',
      _ => 'end',
    };
    try {
      await _repository.action(call.id, action);
    } catch (_) {
      // Local media must stop even if the final lifecycle request times out.
    }
    await _finishLocal(VoiceCallPhase.ended);
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
          state = state.copyWith(call: call);
          unawaited(
            _finishLocal(
              type == 'call.failed'
                  ? VoiceCallPhase.failed
                  : VoiceCallPhase.ended,
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
    await AndroidCallUi.showIncomingFromCall(call);
  }

  Future<void> _onAccepted(VoiceCall call) async {
    if (state.call?.id != call.id) return;
    if (state.phase == VoiceCallPhase.incomingRinging && !_transitioning) {
      // Another Android device signed in to the same callee answered first.
      state = state.copyWith(call: call);
      await _finishLocal(VoiceCallPhase.ended);
      return;
    }
    if (!state.outgoing || _engine != null) return;
    try {
      final session = VoiceCallSession(
        call: call,
        iceServers: state.iceServers,
      );
      state = state.copyWith(phase: VoiceCallPhase.connecting, call: call);
      _ringTimer?.cancel();
      await _prepareEngine(session);
      await _engine!.createAndSendOffer();
    } catch (error) {
      await _failLocal('offer_failed', error);
    }
  }

  Future<void> _prepareEngine(VoiceCallSession session) async {
    final call = session.call;
    final engine = VoicePeerEngine(
      sendSignal: (signal) => _ws.sendWhenConnected({
        'type': 'call.signal',
        'call_id': call.id,
        'signal': signal,
      }),
      onConnected: () {
        if (state.call?.id != call.id) return;
        state = state.copyWith(
          phase: VoiceCallPhase.connected,
          connectedAt: DateTime.now(),
          clearError: true,
        );
        unawaited(FlutterCallkitIncoming.setCallConnected(call.id));
      },
      onFailed: (reason) => unawaited(_failLocal(reason)),
    );
    _engine = engine;
    await engine.prepare(iceServers: session.iceServers);
    // VoicePeerEngine starts Android calls on speaker for an audible default.
    state = state.copyWith(speaker: true);
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
    if (callId != null && !state.call!.isTerminal) {
      try {
        await _repository.action(callId, 'fail', reason: reason);
      } catch (_) {}
    }
    state = state.copyWith(
      phase: VoiceCallPhase.failed,
      error: error == null ? _failureLabel(reason) : _friendlyError(error),
    );
    await _finishLocal(VoiceCallPhase.failed, preserveError: true);
  }

  Future<void> _finishLocal(
    VoiceCallPhase phase, {
    bool preserveError = false,
  }) async {
    _ringTimer?.cancel();
    await _engine?.dispose();
    _engine = null;
    _pendingSignals.clear();
    final callId = state.call?.id;
    if (callId != null) await _endNative(callId);
    state = state.copyWith(
      phase: phase,
      clearConnectedAt: false,
      clearError: !preserveError,
    );
    _scheduleReset();
  }

  Future<void> _endNative(String callId) async {
    _suppressNativeEnd = true;
    try {
      await FlutterCallkitIncoming.endCall(callId);
    } catch (_) {
    } finally {
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        _suppressNativeEnd = false;
      });
    }
  }

  void _handleNativeEvent(CallEvent? event) {
    if (event == null) return;
    switch (event) {
      case CallEventActionCallAccept(:final callKitParams):
        unawaited(acceptIncoming(callKitParams.id));
      case CallEventActionCallDecline(:final callKitParams):
        unawaited(declineIncoming(callKitParams.id));
      case CallEventActionCallEnded(:final callKitParams):
        if (!_suppressNativeEnd && state.call?.id == callKitParams.id) {
          unawaited(hangUp());
        }
      case CallEventActionCallTimeout(:final id):
        if (state.call?.id == id) {
          unawaited(_finishLocal(VoiceCallPhase.ended));
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
        await _endNative(native.id);
        return;
      }
      state = VoiceCallState(
        phase: VoiceCallPhase.incomingRinging,
        call: session.call,
        iceServers: session.iceServers,
        currentUserId: state.currentUserId,
      );
      if (native.isAccepted) {
        await acceptIncoming(native.id);
      } else {
        _startRingTimer(session.call);
      }
    } catch (_) {
      // No recoverable native call.
    }
  }

  void _startRingTimer(VoiceCall call) {
    _ringTimer?.cancel();
    final remaining = call.expiresAt.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      unawaited(_finishLocal(VoiceCallPhase.ended));
      return;
    }
    _ringTimer = Timer(remaining + const Duration(seconds: 1), () {
      if (state.call?.id == call.id &&
          (state.phase == VoiceCallPhase.incomingRinging ||
              state.phase == VoiceCallPhase.outgoingRinging)) {
        unawaited(_finishLocal(VoiceCallPhase.ended));
      }
    });
  }

  void _scheduleReset() {
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 5), reset);
  }

  Future<void> _ensureCallPermissions() async {
    final microphone = await Permission.microphone.request();
    if (!microphone.isGranted) {
      throw StateError('microphone permission denied');
    }
    // Bluetooth is optional; a denied request falls back to earpiece/speaker.
    await Permission.bluetoothConnect.request();
  }

  Future<void> _resetResources() async {
    _ringTimer?.cancel();
    _resetTimer?.cancel();
    await _engine?.dispose();
    _engine = null;
    _pendingSignals.clear();
  }

  String _friendlyError(Object error) {
    final apiError = _apiError(error);
    final value = '$apiError ${error.toString()}';
    if (value.contains('voice_call_busy')) return 'This person is busy.';
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
    if (value.toLowerCase().contains('permission')) {
      return 'Microphone permission is required for calls.';
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
    if (reason == 'signaling_unavailable') {
      return 'The realtime connection was lost.';
    }
    return 'The call could not connect.';
  }

  Future<void> dispose() async {
    await shutdown();
  }
}

final voiceCallProvider = NotifierProvider<VoiceCallNotifier, VoiceCallState>(
  VoiceCallNotifier.new,
);
