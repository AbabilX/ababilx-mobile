import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../data/models/ice_server.dart';
import '../audio/call_audio_route.dart';
import '../native/android_screen_share.dart';
import '../voice_call_log.dart';
import 'ice_candidate_stats.dart';
import 'voice_audio_progress.dart';
import 'voice_camera_capture.dart';
import 'voice_media_map.dart';
import 'voice_video_quality.dart';

typedef VoiceSignalSender = Future<bool> Function(Map<String, dynamic> signal);

/// iOS/macOS only — Android has no native `ensureAudioSession` method and
/// throws [MissingPluginException], which previously aborted every accept.
Future<void> _ensureAudioSessionIfNeeded() async {
  if (!Platform.isIOS && !Platform.isMacOS) return;
  try {
    await Helper.ensureAudioSession();
  } catch (_) {
    // Non-fatal: getUserMedia / peer connection still proceed.
  }
}

/// Debug switch: force ALL media through TURN relay to isolate the relay path.
///
/// When true the peer connection discards host/srflx candidates and can only
/// connect if a `relay` candidate works end-to-end. Use it to prove whether
/// coturn's relay media ports (not just the 3478 control port) are reachable:
///   connects with relay-only  → relay path healthy
///   fails    with relay-only  → allocation succeeds but relay media is blocked
///                                (Docker port range / UFW / cloud firewall)
/// Leave false for production — it removes the same-LAN fast path.
const bool kForceRelayTransport = bool.fromEnvironment(
  'FORCE_RELAY',
  defaultValue: false,
);

class VoicePeerEngine {
  VoicePeerEngine({
    required this.sendSignal,
    required this.onConnected,
    required this.onFailed,
    required this.onTrouble,
    required this.onHealthy,
    required this.onRestartRequested,
    required this.onLocalScreenChanged,
    required this.onRemoteScreenChanged,
    required this.onLocalCameraChanged,
    required this.onRemoteCameraChanged,
    required this.isOfferer,
  });

  /// True on the side that placed the call.
  ///
  /// Exactly one side is allowed to create offers. flutter_webrtc has no SDP
  /// rollback, so a peer that receives an offer while holding one of its own
  /// can never apply it — there is no way back to `stable`. Glare therefore
  /// cannot be resolved after the fact here, only avoided: the callee asks the
  /// caller to re-offer instead of offering itself. Every renegotiation a
  /// video call needs (camera on/off, screen share, ICE restart) goes through
  /// this one funnel.
  final bool isOfferer;

  final VoiceSignalSender sendSignal;
  final void Function() onConnected;

  /// Unrecoverable: signalling is gone, so no restart can be negotiated.
  final void Function(String reason) onFailed;

  /// The media path dropped. Recoverable by an ICE restart — the owner decides
  /// whether to retry or give up, this engine only reports the transition.
  final void Function(String reason, {bool immediate}) onTrouble;

  /// Media is flowing. Fires on every entry to `connected`, not just the first,
  /// so a recovery in progress can be cleared.
  final void Function() onHealthy;

  /// The peer asked us to run the ICE restart (only the caller re-offers).
  final void Function() onRestartRequested;

  final void Function(bool sharing) onLocalScreenChanged;
  final void Function(MediaStream? stream) onRemoteScreenChanged;

  /// The local camera preview, or null once it is off. Carries the facing so
  /// the preview knows whether to mirror.
  final void Function(MediaStream? stream, {required bool front})
  onLocalCameraChanged;
  final void Function(MediaStream? stream) onRemoteCameraChanged;

  RTCPeerConnection? _peer;
  MediaStream? _localStream;
  MediaStream? _screenStream;
  MediaStream? _remoteScreenStream;
  RTCRtpSender? _screenSender;
  VoiceCameraCapture? _camera;
  RTCRtpSender? _cameraSender;
  final VoiceMediaMap _remoteMedia = VoiceMediaMap();
  MediaStream? _remoteCameraShown;
  final List<MediaStream> _remoteStreams = [];
  final List<RTCIceCandidate> _pendingCandidates = [];
  final IceCandidateStats _localCandidates = IceCandidateStats();
  bool _remoteDescriptionSet = false;
  bool _disposed = false;
  bool _connected = false;
  final _audioProgress = VoiceAudioProgress();
  Timer? _audioHealthTimer;
  bool _audioHealthPending = false;
  bool _answerReceived = false;

  /// Counts remote offers applied, so the fallback below can tell whether the
  /// peer answered a renegotiation request or ignored it.
  int _remoteOffers = 0;
  Timer? _renegotiateFallback;

  bool get ready => _peer != null && _localStream != null;

  bool get hasRemoteDescription => _remoteDescriptionSet;

  bool get answerReceived => _answerReceived;

  bool get cameraOn => _camera != null;

  /// Speaker pressed by the user, before or during [prepare]; null = never.
  bool? _speakerChoice;

  /// The route this call is on: the user's choice, else loudspeaker for a
  /// call with the camera open (the phone is held out) and earpiece otherwise.
  bool get speakerOn => CallAudioRoute.startsOnSpeaker(
    chosen: _speakerChoice,
    camera: _camera != null,
  );

  /// [video] opens the camera before the first offer/answer so a video call
  /// negotiates once. Starting it after `connected` instead would have both
  /// sides re-offer at the same instant, and colliding offers are dropped.
  /// A camera that cannot open (permission, hardware) degrades to audio.
  ///
  /// [speaker] is a Speaker press made while the call was still ringing, when
  /// there was nothing to route. Forcing the earpiece here regardless is what
  /// sent a caller who chose the loudspeaker back to the earpiece on answer.
  Future<void> prepare({
    required List<IceServer> iceServers,
    bool video = false,
    bool? speaker,
  }) async {
    if (_disposed) throw StateError('Voice peer engine is disposed');
    if (ready) return;
    // A press that reached this engine already (while the camera permission
    // was asked) is newer than the one the caller read before.
    _speakerChoice ??= speaker;

    final hasTurn = iceServers.any(
      (s) =>
          s.urls.any((u) => u.startsWith('turn:') || u.startsWith('turns:')) &&
          (s.username?.isNotEmpty ?? false),
    );
    voiceCallLog(
      'engine.ice.config',
      reason: hasTurn
          ? 'stun+turn servers=${iceServers.length}'
          : 'stun_only servers=${iceServers.length} (cellular may stall)',
    );

    // Communication mode and audio focus before the microphone is opened, so
    // capture and routing start in a call session rather than in media mode.
    // Not `Helper.setAndroidAudioConfiguration`: that configures flutter_webrtc's
    // audio manager, which LiveKit disables app-wide — see [CallAudioRoute].
    // Earpiece, like every dialler: a call answered and lifted to the ear must
    // not come out of the loudspeaker — unless Speaker was already pressed.
    // `CallScreenLock`'s proximity blanking keys off this same route.
    await CallAudioRoute.activate(speaker: _speakerChoice ?? false);
    if (_disposed) return;
    await _ensureAudioSessionIfNeeded();
    if (_disposed) return;
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    });
    if (_disposed) {
      for (final track in stream.getTracks()) {
        await track.stop();
      }
      await stream.dispose();
      return;
    }
    _localStream = stream;

    final peer = await createPeerConnection({
      'iceServers': iceServers.map((server) => server.toWebRtcJson()).toList(),
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
      if (kForceRelayTransport) 'iceTransportPolicy': 'relay',
    });
    if (_disposed) {
      await peer.close();
      await peer.dispose();
      return;
    }
    if (kForceRelayTransport) {
      voiceCallLog(
        'engine.ice.forceRelay',
        reason: 'iceTransportPolicy=relay (debug: relay-only test)',
      );
    }
    _peer = peer;
    peer.onIceCandidate = (candidate) {
      final value = candidate.candidate;
      if (value == null || value.isEmpty || _disposed) return;
      _localCandidates.add(value);
      unawaited(
        sendSignal({
          'kind': 'ice',
          'candidate': value,
          'sdp_mid': candidate.sdpMid ?? '',
          'sdp_mline_index': candidate.sdpMLineIndex,
        }),
      );
    };
    peer.onIceGatheringState = (state) {
      if (_disposed) return;
      if (state != RTCIceGatheringState.RTCIceGatheringStateComplete) return;
      voiceCallLog('ice.gathered', reason: _localCandidates.toString());
      if (_localCandidates.lanOnly) {
        // Not fatal on its own (same-LAN calls still connect), but it is the
        // single most useful line when a cross-network call never connects.
        voiceCallLog(
          'ice.gathered.warning',
          reason:
              'no srflx/relay — STUN/TURN unreachable, '
              'only same-network calls can connect',
        );
      }
    };
    peer.onIceConnectionState = (state) {
      if (_disposed) return;
      voiceCallLog('ice.connection', reason: state.toString());
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        onTrouble(_failureReason(), immediate: true);
      } else if (_connected &&
          (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
              state == RTCIceConnectionState.RTCIceConnectionStateCompleted)) {
        onHealthy();
      }
    };
    peer.onConnectionState = _handleConnectionState;
    peer.onTrack = (event) {
      if (_disposed) return;
      if (event.track.kind == 'video') {
        final remote = event.streams.isNotEmpty ? event.streams.first : null;
        if (remote == null) return;
        _remoteMedia.streams[remote.id] = remote;
        _syncRemoteVideo();
        event.track.onEnded = () {
          if (_disposed) return;
          _remoteMedia.streams.remove(remote.id);
          _syncRemoteVideo();
        };
        return;
      }
      if (event.track.kind != 'audio') return;
      event.track.enabled = true;
      for (final stream in event.streams) {
        if (!_remoteStreams.contains(stream)) _remoteStreams.add(stream);
      }
      // Native WebRTC plays remote audio itself. This explicitly restores the
      // track volume in case Android had previously muted its audio route.
      unawaited(Helper.setVolume(1.0, event.track));
    };

    for (final track in stream.getAudioTracks()) {
      if (_disposed) return;
      await peer.addTrack(track, stream);
    }
    if (video) {
      try {
        await startCamera(renegotiate: false);
      } catch (e) {
        voiceCallLog('camera.open.failed', reason: e.toString());
      }
    }
    // Re-assert the route once media is attached: opening the microphone can
    // move the phone off its route on its own. `force` is false for the
    // earpiece on purpose, so a connected headset still wins. Read after every
    // await above, so a press made while media was opening is the one applied.
    if (!_disposed) await CallAudioRoute.setSpeaker(speakerOn);
  }

  // ---- camera -------------------------------------------------------------

  /// One video lane at a time: turning the camera on ends a running screen
  /// share, and the single renegotiation below carries both changes.
  Future<void> startCamera({bool front = true, bool renegotiate = true}) async {
    if (_camera != null || _disposed) return;
    final peer = _requirePeer();
    final droppedScreen = _screenStream != null;
    if (droppedScreen) await stopScreenShare(renegotiate: false);
    final camera = await VoiceCameraCapture.open(front: front);
    if (_disposed) {
      await camera.close();
      return;
    }
    _camera = camera;
    var needsOffer = false;
    try {
      final sender = _cameraSender;
      if (sender != null) {
        // The transceiver from an earlier camera session is still there; a
        // replaceTrack needs no renegotiation and the far side keeps drawing
        // the stream it already holds under the original id.
        await sender.replaceTrack(camera.track);
      } else {
        _cameraSender = await peer.addTrack(camera.track, camera.stream);
        _cameraWireStreamId = camera.stream.id;
        needsOffer = true;
      }
      final cameraSender = _cameraSender;
      if (cameraSender != null) {
        await capVideoSendBitrate(
          cameraSender,
          maxBitrate: kCameraMaxBitrate,
          maintainResolution: false,
        );
      }
    } catch (_) {
      _camera = null;
      await camera.close();
      rethrow;
    }
    onLocalCameraChanged(camera.stream, front: camera.front);
    if (!renegotiate) return; // the caller's offer/answer sends the map
    await _sendMediaMap();
    if (needsOffer || droppedScreen) await _renegotiate();
  }

  /// The stream id the far side learned at addTrack time. A later camera
  /// session captures a fresh stream, but replaceTrack keeps the wire msid,
  /// so this is the id the media map has to name.
  String? _cameraWireStreamId;

  Future<void> stopCamera() async {
    final camera = _camera;
    if (camera == null) return;
    _camera = null;
    try {
      await _cameraSender?.replaceTrack(null);
    } catch (e) {
      voiceCallLog('camera.replaceTrack.failed', reason: e.toString());
    }
    await camera.close();
    onLocalCameraChanged(null, front: camera.front);
    if (!_disposed) await _sendMediaMap();
  }

  Future<void> switchCamera() async {
    final camera = _camera;
    if (camera == null) return;
    await camera.switchCamera();
    onLocalCameraChanged(camera.stream, front: camera.front);
  }

  /// Pauses capture without tearing the transceiver down — the app went to
  /// the background, where Android revokes the camera anyway.
  Future<void> setCameraPaused(bool paused) async {
    final camera = _camera;
    if (camera == null) return;
    camera.track.enabled = !paused;
  }

  /// Tells the far side which of our stream ids is the camera and which the
  /// screen. Sent before any offer/answer that touches video, and again on
  /// every camera flip so a peer can clear its view without a renegotiation.
  Future<void> _sendMediaMap() async {
    if (_disposed) return;
    await sendSignal({
      'kind': 'media',
      'camera_stream': _camera == null ? '' : (_cameraWireStreamId ?? ''),
      'screen_stream': _screenStream?.id ?? '',
    });
  }

  void _syncRemoteVideo() {
    final camera = _remoteMedia.camera;
    if (!identical(camera, _remoteCameraShown)) {
      _remoteCameraShown = camera;
      onRemoteCameraChanged(camera);
    }
    final screen = _remoteMedia.screen;
    if (!identical(screen, _remoteScreenStream)) {
      _remoteScreenStream = screen;
      onRemoteScreenChanged(screen);
    }
  }

  Future<void> createAndSendOffer({bool renegotiate = false}) async {
    final peer = _requirePeer();
    if (!renegotiate) {
      if (_camera != null) await _sendMediaMap();
      final offer = await peer.createOffer({
        'mandatory': {'OfferToReceiveAudio': true, 'OfferToReceiveVideo': true},
      });
      await peer.setLocalDescription(offer);
    }
    final local = await peer.getLocalDescription();
    final sdp = local?.sdp;
    if (sdp == null || sdp.isEmpty) {
      onFailed('signaling_unavailable');
      return;
    }
    final sent = await sendSignal({'kind': 'offer', 'sdp': sdp});
    voiceCallLog(
      'signal.offer.send',
      reason: sent ? (renegotiate ? 'retry_ok' : 'ok') : 'ws_unavailable',
    );
    if (!sent) onFailed('signaling_unavailable');
  }

  Future<void> handleSignal(Map<String, dynamic> signal) async {
    if (_disposed) return;
    final kind = signal['kind'] as String? ?? '';
    switch (kind) {
      case 'offer':
        final sdp = signal['sdp'] as String? ?? '';
        if (sdp.isEmpty) return;
        if (await _requirePeer().getSignalingState() !=
            RTCSignalingState.RTCSignalingStateStable) {
          // Glare. Applying this would throw, and that thrown error used to
          // end the call on both phones at once. With no SDP rollback in
          // flutter_webrtc there is nothing else this side can do: drop their
          // offer, keep ours, and let them re-offer after it is answered.
          // Checked before anything below mutates state for an offer that is
          // not going to be applied. Only a peer on a build that predates the
          // single-offerer rule can reach here.
          voiceCallLog('signal.offer.glare', reason: 'ignored_remote_offer');
          return;
        }
        if (!_remoteMedia.received &&
            !_sdpSendsVideo(sdp) &&
            _remoteScreenStream != null) {
          // Legacy peer with no media map: a re-offer without video means
          // its screen share stopped.
          _remoteMedia.clear();
          _syncRemoteVideo();
        }
        final peer = _requirePeer();
        await peer.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
        _remoteDescriptionSet = true;
        _remoteOffers++;
        _renegotiateFallback?.cancel();
        if (_camera != null || _screenStream != null) await _sendMediaMap();
        final answer = await peer.createAnswer({
          'mandatory': {
            'OfferToReceiveAudio': true,
            'OfferToReceiveVideo': true,
          },
        });
        await peer.setLocalDescription(answer);
        final sent = await sendSignal({'kind': 'answer', 'sdp': answer.sdp});
        voiceCallLog(
          'signal.answer.send',
          reason: sent ? 'ok' : 'ws_unavailable',
        );
        if (!sent) onFailed('signaling_unavailable');
        // A stale or unsupported trickled candidate must not prevent the SDP
        // answer from reaching the caller. Other candidates can still connect.
        await _flushCandidates();
      case 'answer':
        final sdp = signal['sdp'] as String? ?? '';
        if (sdp.isEmpty) return;
        await _requirePeer().setRemoteDescription(
          RTCSessionDescription(sdp, 'answer'),
        );
        _remoteDescriptionSet = true;
        _answerReceived = true;
        await _flushCandidates();
      case 'restart':
        onRestartRequested();
      // The peer's tracks changed and it may not offer. Nothing to do with
      // ICE, so this never enters the reconnect path.
      case 'renegotiate':
        if (isOfferer) {
          await _ensureVideoRecvCapacity();
          await _renegotiate();
        }
      // The peer has started sharing and there is only ever one shared screen
      // in a 1:1 call. No-op unless we are the one sharing.
      case 'screen_takeover':
        await stopScreenShare();
      case 'media':
        _remoteMedia.apply(signal);
        _syncRemoteVideo();
      case 'ice':
        final candidate = signal['candidate'] as String? ?? '';
        if (candidate.isEmpty) return;
        // Server contract is snake_case; accept camelCase defensively.
        final sdpMid =
            (signal['sdp_mid'] as String?) ?? (signal['sdpMid'] as String?);
        final rawIndex = signal['sdp_mline_index'] ?? signal['sdpMLineIndex'];
        final sdpMLineIndex = rawIndex is num ? rawIndex.toInt() : null;
        final parsed = RTCIceCandidate(candidate, sdpMid, sdpMLineIndex);
        if (!_remoteDescriptionSet) {
          _pendingCandidates.add(parsed);
        } else {
          await _addCandidate(parsed);
        }
    }
  }

  void _handleConnectionState(RTCPeerConnectionState state) {
    if (_disposed) return;
    voiceCallLog('pc.state', reason: state.toString());
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        unawaited(_ensureAudioSessionIfNeeded());
        onHealthy();
        if (!_connected) {
          _connected = true;
          onConnected();
          _audioHealthTimer = Timer.periodic(
            const Duration(seconds: 2),
            (_) => unawaited(_checkAudioHealth()),
          );
          // One-shot pair snapshot, then a 5s follow-up to confirm media flow.
          unawaited(logSelectedPair());
          Timer(const Duration(seconds: 5), () => unawaited(logMediaFlow()));
        }
      // Neither state recovers on its own — the candidate pair that was
      // carrying media is gone. An ICE restart is the only cure, so both are
      // reported as trouble rather than ending the call here. `failed` is
      // terminal for this pair and skips the settle grace; `disconnected` is
      // often a blip worth waiting out.
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        onTrouble(_failureReason(), immediate: true);
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        onTrouble('peer_connection_disconnected', immediate: false);
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
      case RTCPeerConnectionState.RTCPeerConnectionStateNew:
      case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
        break;
    }
  }

  /// Distinguishes "the connection dropped" from "no route could ever exist".
  String _failureReason() =>
      _localCandidates.lanOnly ? 'ice_no_relay' : 'peer_connection_failed';

  // Network notifications and ICE restarts need not produce a new aggregate
  // PC connected event. Fresh incoming audio also ends a recovery episode.
  Future<void> _checkAudioHealth() async {
    final peer = _peer;
    if (_disposed || peer == null || _audioHealthPending) return;
    _audioHealthPending = true;
    try {
      final stats = await peer.getStats();
      if (_disposed || !identical(peer, _peer)) return;
      final packets = <String, num>{};
      for (final report in stats) {
        final values = report.values;
        if (report.type == 'inbound-rtp' &&
            (values['kind'] ?? values['mediaType']) == 'audio' &&
            values['packetsReceived'] is num) {
          packets[report.id] = values['packetsReceived'] as num;
        }
      }
      if (_audioProgress.update(packets)) onHealthy();
    } catch (_) {
      // An unavailable stats sample is not evidence of call failure.
      _audioProgress.update({});
    } finally {
      _audioHealthPending = false;
    }
  }

  Future<void> _flushCandidates() async {
    for (final candidate in _pendingCandidates) {
      await _addCandidate(candidate);
    }
    _pendingCandidates.clear();
  }

  Future<void> _addCandidate(RTCIceCandidate candidate) async {
    try {
      await _requirePeer().addCandidate(candidate);
    } catch (error) {
      // ICE is opportunistic. Keep negotiating through the remaining
      // host/srflx/relay candidates and retain a useful diagnostic trace.
      voiceCallLog('ice.candidate.ignored', reason: error.toString());
    }
  }

  /// Logs the negotiated candidate pair — the single most useful line for a
  /// cross-network call: shows whether media rides host / srflx / relay and
  /// over UDP or TCP. `relay/relay` here while audio is silent points squarely
  /// at the TURN relay media ports, not the mobile client.
  Future<void> logSelectedPair() async {
    final peer = _peer;
    if (peer == null || _disposed) return;
    try {
      final stats = await peer.getStats();
      final byId = {for (final r in stats) r.id: r.values};
      for (final report in stats) {
        if (report.type != 'candidate-pair') continue;
        final v = report.values;
        final selected = v['selected'] == true || v['state'] == 'succeeded';
        if (!selected) continue;
        final local = byId[v['localCandidateId']] ?? const {};
        final remote = byId[v['remoteCandidateId']] ?? const {};
        voiceCallLog(
          'stats.selectedPair',
          reason:
              'local=${local['candidateType']}/${local['protocol']} '
              'remote=${remote['candidateType']}/${remote['protocol']} '
              'rtt=${v['currentRoundTripTime']}',
        );
        return;
      }
      voiceCallLog('stats.selectedPair', reason: 'no_succeeded_pair');
    } catch (e) {
      voiceCallLog('stats.selectedPair.error', reason: e.toString());
    }
  }

  /// Confirms bytes are actually crossing the wire. Zero received a few seconds
  /// after "connected" means signalling/ICE worked but media is not flowing —
  /// e.g. relay allocated but relay port blocked, or wrong audio route.
  Future<void> logMediaFlow() async {
    final peer = _peer;
    if (peer == null || _disposed) return;
    try {
      final stats = await peer.getStats();
      for (final report in stats) {
        final v = report.values;
        if (report.type == 'inbound-rtp' && v['kind'] == 'audio') {
          voiceCallLog(
            'stats.inbound',
            reason:
                'bytesRecv=${v['bytesReceived']} '
                'packetsRecv=${v['packetsReceived']} '
                'lost=${v['packetsLost']} jitter=${v['jitter']}',
          );
        } else if (report.type == 'outbound-rtp' && v['kind'] == 'audio') {
          voiceCallLog(
            'stats.outbound',
            reason:
                'bytesSent=${v['bytesSent']} '
                'packetsSent=${v['packetsSent']}',
          );
        }
      }
    } catch (e) {
      voiceCallLog('stats.mediaFlow.error', reason: e.toString());
    }
  }

  Future<void> setMuted(bool muted) async {
    for (final track in _localStream?.getAudioTracks() ?? const []) {
      track.enabled = !muted;
      await Helper.setMicrophoneMute(muted, track);
    }
  }

  Future<void> setSpeaker(bool enabled) {
    _speakerChoice = enabled;
    return CallAudioRoute.setSpeaker(enabled);
  }

  /// Sharing a screen turns the camera off: the far side shows one or the
  /// other, never both. The share's own renegotiation covers the swap.
  ///
  /// [takeover]: the peer is sharing. It is told to stop the moment our
  /// capture exists — after the picker, so a dismissed one leaves their share
  /// running, but before our renegotiation round trip, which used to leave
  /// both shares live for seconds. Their screen leaves our view at once.
  Future<void> startScreenShare({bool takeover = false}) async {
    if (_screenStream != null) return;
    final peer = _requirePeer();
    await stopCamera();
    if (Platform.isAndroid) {
      final granted = await Helper.requestCapturePermission();
      if (!granted) throw StateError('screen capture permission denied');
      await AndroidScreenShare.start();
    }

    MediaStream? stream;
    try {
      stream = await navigator.mediaDevices.getDisplayMedia({
        'audio': false,
        'video': {'frameRate': 15},
      });
      final tracks = stream.getVideoTracks();
      if (tracks.isEmpty) {
        throw StateError('screen capture returned no video track');
      }
      final track = tracks.first;
      if (takeover) await _takeScreenFromPeer();
      _screenStream = stream;
      _screenSender = await peer.addTrack(track, stream);
      await capVideoSendBitrate(
        _screenSender!,
        maxBitrate: kScreenMaxBitrate,
        maintainResolution: true,
      );
      onLocalScreenChanged(true);
      track.onEnded = () => unawaited(stopScreenShare());
      await _sendMediaMap();
      await _renegotiate();
    } catch (_) {
      if (_screenStream != null) {
        await stopScreenShare(renegotiate: false);
      } else if (stream != null) {
        for (final track in stream.getTracks()) {
          await track.stop();
        }
        await stream.dispose();
        await AndroidScreenShare.stop();
      }
      rethrow;
    }
  }

  /// "I am taking the screen share" — the peer stops sharing its own, and we
  /// stop drawing it now rather than after their renegotiation lands.
  Future<void> _takeScreenFromPeer() async {
    if (_disposed) return;
    await sendSignal({'kind': 'screen_takeover'});
    _remoteMedia
      ..received = true
      ..screenId = null;
    _syncRemoteVideo();
  }

  Future<void> stopScreenShare({bool renegotiate = true}) async {
    final stream = _screenStream;
    if (stream == null) return;
    final sender = _screenSender;
    final peer = _peer;
    _screenStream = null;
    _screenSender = null;
    for (final track in stream.getVideoTracks()) {
      track.onEnded = null;
    }
    if (peer != null && sender != null) await peer.removeTrack(sender);
    for (final track in stream.getTracks()) {
      await track.stop();
    }
    await stream.dispose();
    await AndroidScreenShare.stop();
    onLocalScreenChanged(false);
    if (renegotiate && peer != null && !_disposed) {
      await _sendMediaMap();
      await _renegotiate();
    }
  }

  /// Swaps in freshly-issued ICE servers without tearing the call down.
  ///
  /// Matters on long calls: coturn REST credentials are timestamped, so a call
  /// outliving its TURN credential loses the relay on the next allocation
  /// refresh. Re-fetching before a restart means the new candidates are
  /// gathered with credentials that are valid again.
  Future<void> applyIceServers(List<IceServer> iceServers) async {
    if (_disposed || iceServers.isEmpty) return;
    await _requirePeer().setConfiguration({
      'iceServers': iceServers.map((server) => server.toWebRtcJson()).toList(),
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
      if (kForceRelayTransport) 'iceTransportPolicy': 'relay',
    });
  }

  /// Gathers a new set of candidates over the existing connection and offers
  /// them. Call only on the side that owns the offer (the original caller);
  /// simultaneous offers collide and neither is applied.
  Future<void> restartIce() async {
    if (_disposed) return;
    final peer = _requirePeer();
    await peer.restartIce();
    // restartIce() only arms the flag — the fresh ufrag/pwd appear in the next
    // offer, so the renegotiation below is what actually moves the call.
    await _renegotiate();
  }

  /// Asks the peer to run [restartIce]. Used by the callee, which must not
  /// offer on its own.
  Future<void> requestRestart() async {
    if (_disposed) return;
    final sent = await sendSignal({'kind': 'restart'});
    voiceCallLog('signal.restart.send', reason: sent ? 'ok' : 'ws_unavailable');
  }

  /// `OfferToReceiveVideo` guarantees one video line, and one is not always
  /// enough. A peer that has ever sent its camera keeps that transceiver for a
  /// later replaceTrack, and WebRTC never reuses one that has sent — so its
  /// screen share needs a line of its own, or it is never sent at all ("video
  /// call, then share: the other side sees nothing"). The media map names the
  /// stream before the request arrives, which is how this knows.
  Future<void> _ensureVideoRecvCapacity() async {
    if (!_remoteMedia.awaiting) return;
    await _requirePeer().addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
    );
  }

  /// The one place a mid-call offer can come from.
  ///
  /// The callee never offers; it asks the caller to, and answers what comes
  /// back. `OfferToReceiveVideo` on the caller's offer is what makes that
  /// work: it puts a video m-line on the wire, and the callee's own pending
  /// track — added by `addTrack` and not yet associated with anything — is
  /// bound to it when the offer is applied. So a camera the callee turned on
  /// still reaches the caller, without the callee ever having to offer.
  Future<void> _renegotiate() async {
    if (_disposed) return;
    if (isOfferer) return _offerDirectly();
    // Ask, do not offer. Deliberately not the `restart` signal: that one routes
    // through the reconnect controller and paints "Reconnecting…" over a call
    // that is perfectly healthy and merely turning a camera on.
    final sent = await sendSignal({'kind': 'renegotiate'});
    if (!sent) throw StateError('signaling_unavailable');
    _armRenegotiateFallback();
  }

  /// A server that predates the `renegotiate` signal drops it without telling
  /// anyone — the socket accepted the frame, so [sendSignal] reports success.
  /// If no offer has arrived by the time this fires, fall back to offering
  /// directly, which is what this side used to do unconditionally.
  void _armRenegotiateFallback() {
    _renegotiateFallback?.cancel();
    final before = _remoteOffers;
    _renegotiateFallback = Timer(const Duration(seconds: 4), () async {
      if (_disposed || _remoteOffers != before) return;
      voiceCallLog('signal.renegotiate.fallback', reason: 'no_offer_in_4s');
      try {
        // This side is the callee: offering is only valid from `stable`.
        if (await _requirePeer().getSignalingState() !=
            RTCSignalingState.RTCSignalingStateStable) {
          return;
        }
        await _offerDirectly();
      } catch (error) {
        voiceCallLog(
          'signal.renegotiate.fallback.failed',
          reason: error.toString(),
        );
      }
    });
  }

  /// Creates and sends an offer.
  ///
  /// No stability check: replacing an offer this side already has outstanding
  /// is legal, and it is exactly what an ICE restart does when the first offer
  /// was lost. Refusing here left a recovery with nothing to send and the call
  /// died when the reconnect budget ran out.
  Future<void> _offerDirectly() async {
    final peer = _requirePeer();
    final offer = await peer.createOffer({
      'mandatory': {'OfferToReceiveAudio': true, 'OfferToReceiveVideo': true},
    });
    await peer.setLocalDescription(offer);
    if (!await sendSignal({'kind': 'offer', 'sdp': offer.sdp})) {
      throw StateError('signaling_unavailable');
    }
  }

  bool _sdpSendsVideo(String sdp) {
    final sections = sdp.split(RegExp(r'(?=m=)'));
    for (final section in sections) {
      if (!section.startsWith('m=video ')) continue;
      final direction = RegExp(
        r'^a=(sendrecv|sendonly|recvonly|inactive)\r?$',
        multiLine: true,
      ).firstMatch(section)?.group(1);
      return direction == null ||
          direction == 'sendrecv' ||
          direction == 'sendonly';
    }
    return false;
  }

  RTCPeerConnection _requirePeer() {
    final peer = _peer;
    if (peer == null) throw StateError('Voice peer is not prepared');
    return peer;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _audioHealthTimer?.cancel();
    _audioHealthTimer = null;
    await stopScreenShare(renegotiate: false);
    _renegotiateFallback?.cancel();
    _renegotiateFallback = null;
    final camera = _camera;
    _camera = null;
    _cameraSender = null;
    _cameraWireStreamId = null;
    if (camera != null) {
      await camera.close();
      onLocalCameraChanged(null, front: camera.front);
    }
    _remoteMedia.clear();
    _remoteCameraShown = null;
    onRemoteCameraChanged(null);
    for (final track in _localStream?.getTracks() ?? const []) {
      await track.stop();
    }
    await _localStream?.dispose();
    _localStream = null;
    _remoteStreams.clear();
    _remoteScreenStream = null;
    onRemoteScreenChanged(null);
    await _peer?.close();
    await _peer?.dispose();
    _peer = null;
    await Helper.clearAndroidCommunicationDevice();
    // Give the phone its normal audio mode and focus back; the ringtone and
    // media playback route through the earpiece until this happens.
    await CallAudioRoute.release();
  }
}
