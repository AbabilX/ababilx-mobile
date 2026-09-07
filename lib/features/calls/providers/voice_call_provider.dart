import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/network/ws_client.dart';
import '../../messages/data/models/chat_conversation.dart';
import '../../profile/providers/profile_provider.dart';
import '../call_lifecycle.dart';
import '../callkit_ended_suppress.dart';
import '../data/models/voice_call.dart';
import '../data/models/voice_call_session.dart';
import '../data/voice_call_repository.dart';
import '../incoming_call_ringtone.dart';
import '../native/android_call_ui.dart';
import '../native/android_group_call_ui.dart';
import '../native/incoming_call_admission.dart';
import '../native/answered_elsewhere.dart';
import '../native/call_answered_guard.dart';
import '../native/voice_call_ended_guard.dart';
import '../ringtone/callkit_ring_events.dart';
import '../voice_call_log.dart';
import '../voice_call_ringable.dart';
import '../webrtc/voice_peer_engine.dart';
import '../webrtc/voice_reconnect_controller.dart';
import 'voice_call_state.dart';

export 'voice_call_state.dart';

class VoiceCallNotifier extends Notifier<VoiceCallState> {
  StreamSubscription<Map<String, dynamic>>? _wsSub;
  StreamSubscription<void>? _wsReconnectSub;
  StreamSubscription<CallEvent?>? _nativeSub;
  StreamSubscription<RemoteMessage>? _foregroundPushSub;
  VoicePeerEngine? _engine;
  VoiceReconnectController? _reconnect;
  final List<Map<String, dynamic>> _pendingSignals = [];
  Timer? _ringTimer;
  Timer? _resetTimer;
  Timer? _connectWatchdog;
  Timer? _renegotiateTimer;
  bool _booted = false;
  bool _transitioning = false;
  bool _offerResent = false;
  final Set<String> _finishedCallIds = {};
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
    _foregroundPushSub = FirebaseMessaging.onMessage.listen(
      _handleForegroundCallPush,
    );
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
    await _foregroundPushSub?.cancel();
    _wsSub = null;
    _wsReconnectSub = null;
    _nativeSub = null;
    _foregroundPushSub = null;
    final callId = state.call?.id;
    final currentUserId = state.currentUserId;
    await _resetResources();
    if (callId != null) await _endNative(callId, source: 'shutdown');
    _suppressCallKitEnded.clear();
    _finishedCallIds.clear();
    state = VoiceCallState(currentUserId: currentUserId);
  }

  /// [video] places a video call: the camera opens with the call on both
  /// sides and the callee's ring screen says so. Media is still peer-to-peer.
  Future<void> startOutgoing(
    ChatConversation conversation, {
    bool video = false,
  }) async {
    if (state.active || _transitioning || !conversation.isDm) return;
    if (!conversation.canMessage || conversation.peerUserId == null) {
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
        pendingVideo: video,
      );
      voiceCallLog(
        'start.permission',
        phase: _phaseName,
        source: 'startOutgoing',
      );
      await _ensureCallPermissions();
      if (video) await _ensureCameraPermission();
      voiceCallLog('start.api.begin', source: 'startOutgoing');
      final session = await _repository.start(conversation.id, video: video);
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
    if (callId != null && _wasFinished(callId)) {
      await _endNative(callId, source: 'accept.finished');
      return;
    }
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
    try {
      await _ensureCallPermissions();
      final session = await _acceptOnServer(call.id);
      if (session == null) {
        // Call already finished server-side — end quietly, no error banner.
        await _finishLocal(VoiceCallPhase.ended, reason: 'accept.already_over');
        return;
      }
      voiceCallLog('accept.api.ok', callId: call.id, phase: 'connecting');
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
      if (session.call.isVideo) await _ensureCameraPermission();
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
    // Already leaving the call UI — ignore duplicate Decline taps.
    if (!state.active && callId == null) return;
    // A CallKit decline — from its full-screen UI or from the notification
    // action — usually names a call this provider never loaded, because the
    // push was handled while the app sat in the background. Everything below
    // therefore works from `id`, never from `state.call`: with the state path
    // alone the native record survived the decline, so the ringtone kept its
    // `native` holder and resuming the app recovered the call and rang again.
    _rememberFinished(id);
    if (_transitioning) {
      // Some other transition owns the state machine; the native surface still
      // has to go, or the user is left with a ringing screen they declined.
      await _endNative(id, source: 'decline.transitioning');
      return;
    }
    _transitioning = true;
    voiceCallLog('decline.begin', callId: id, phase: _phaseName);
    // End local UI/ringtone first so Decline feels instant (no second tap).
    final declined = state.call?.copyWith(status: 'declined');
    if (declined != null) {
      state = state.copyWith(call: declined);
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
    } finally {
      _transitioning = false;
    }
  }

  Future<void> hangUp({String source = 'hangUp'}) async {
    if (_transitioning) return;
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
    } finally {
      _transitioning = false;
    }
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

  Future<void> toggleCamera() async {
    final engine = _engine;
    if (engine == null || state.phase != VoiceCallPhase.connected) return;
    try {
      state = state.copyWith(clearCameraError: true);
      if (engine.cameraOn) {
        await engine.stopCamera();
      } else {
        await _ensureCameraPermission();
        if (!await Permission.camera.isGranted) {
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

  Future<void> toggleScreenShare() async {
    final engine = _engine;
    if (engine == null || state.phase != VoiceCallPhase.connected) return;
    if (state.remoteScreenStream != null && !state.screenSharing) return;
    try {
      state = state.copyWith(clearScreenShareError: true);
      if (state.screenSharing) {
        await engine.stopScreenShare();
      } else {
        await engine.startScreenShare();
      }
    } catch (error) {
      voiceCallLog(
        'screenShare.failed',
        callId: state.call?.id,
        phase: _phaseName,
        reason: _debugError(error),
      );
      state = state.copyWith(
        screenShareError: error.toString().toLowerCase().contains('permission')
            ? 'Screen sharing permission was not granted.'
            : 'Could not share this screen.',
      );
    }
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

  Future<void> _onIncoming(VoiceCall call) async {
    if (_wasFinished(call.id) || call.isTerminal) {
      await _endNative(call.id, source: 'incoming.finished');
      return;
    }
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
      // Anything the callee sent while prepare() was still running (mic
      // permission / getUserMedia can take seconds) is queued, not dropped.
      await _flushPendingSignals();
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
      onTrouble: (reason, {bool immediate = false}) {
        if (state.call?.id != callId) return;
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
        if (state.call?.id != callId) return;
        _reconnect?.noteHealthy();
      },
      onRestartRequested: () {
        if (state.call?.id != callId) return;
        _reconnect?.noteRestartRequested();
      },
      onLocalScreenChanged: (sharing) {
        if (state.call?.id != callId) return;
        state = state.copyWith(
          screenSharing: sharing,
          clearScreenShareError: true,
        );
      },
      onRemoteScreenChanged: (stream) {
        if (state.call?.id != callId) return;
        state = state.copyWith(
          remoteScreenStream: stream,
          clearRemoteScreen: stream == null,
        );
      },
      onLocalCameraChanged: (stream, {required bool front}) {
        if (state.call?.id != callId) return;
        state = state.copyWith(
          localCameraStream: stream,
          clearLocalCamera: stream == null,
          cameraFront: front,
          clearCameraError: true,
        );
      },
      onRemoteCameraChanged: (stream) {
        if (state.call?.id != callId) return;
        state = state.copyWith(
          remoteCameraStream: stream,
          clearRemoteCamera: stream == null,
        );
      },
    );
    await engine.prepare(
      iceServers: session.iceServers,
      video: call.isVideo && await Permission.camera.isGranted,
    );
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
    _reconnect = VoiceReconnectController(
      // Only the original caller re-offers; the callee asks it to. Two
      // simultaneous restart offers collide and neither is applied.
      isOfferer: () => state.outgoing,
      restart: () => _restartIce(callId),
      requestPeerRestart: () async => _engine?.requestRestart(),
      onGaveUp: (reason) => unawaited(_failLocal(reason)),
      onReconnectingChanged: (value) {
        if (state.call?.id != callId) return;
        state = state.copyWith(
          reconnectingSince: value ? DateTime.now() : null,
          clearReconnectingSince: !value,
        );
      },
    );
    if (state.muted) {
      await engine.setMuted(true);
    }
    // Mirrors the route VoicePeerEngine just applied (loudspeaker for a call
    // that opened with the camera, earpiece otherwise). Explicit rather than
    // relying on the default, because a previous call in this session may
    // have left the flag on.
    state = state.copyWith(speaker: engine.cameraOn);
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
    String? callId,
  }) async {
    // `callId` is passed when the call being finished is not the one in state
    // — a CallKit decline for a call this isolate never loaded. Falling back
    // to state alone skipped the native dismissal entirely.
    final id = callId ?? state.call?.id;
    _rememberFinished(id);
    voiceCallLog('finishLocal', callId: id, phase: phase.name, reason: reason);
    _ringTimer?.cancel();
    _connectWatchdog?.cancel();
    _renegotiateTimer?.cancel();
    await IncomingCallRingtone.stop();
    await _reconnect?.dispose();
    _reconnect = null;
    await _engine?.dispose();
    _engine = null;
    _pendingSignals.clear();
    _offerResent = false;
    if (id != null) {
      await _endNative(id, source: 'finishLocal.$reason');
    }
    state = state.copyWith(
      phase: phase,
      clearReconnectingSince: true,
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
            (state.phase == VoiceCallPhase.connecting ||
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
    try {
      final session = await _repository.get(callId);
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
      if (_wasFinished(native.id)) {
        await _endNative(native.id, source: 'recover.finished');
        return;
      }
      VoiceCallSession session;
      try {
        session = await _repository.get(native.id);
      } catch (_) {
        // A persisted native record from an old login/offline call is not
        // enough to reopen UI. Recovery requires a live server call.
        await _endNative(native.id, source: 'recover.lookup_failed');
        return;
      }
      if (session.call.isTerminal) {
        _rememberFinished(native.id);
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

  bool _wasFinished(String callId) => _finishedCallIds.contains(callId);

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

  /// Camera is optional on a video call: a refusal degrades to audio rather
  /// than failing the call, so this only throws when asked from a toggle.
  Future<void> _ensureCameraPermission() async {
    if (await Permission.camera.isGranted) return;
    final resumed =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (!resumed) return;
    final status = await Permission.camera.request();
    voiceCallLog(
      'permission.camera',
      callId: state.call?.id,
      reason: status.name,
    );
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
    await _reconnect?.dispose();
    _reconnect = null;
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
