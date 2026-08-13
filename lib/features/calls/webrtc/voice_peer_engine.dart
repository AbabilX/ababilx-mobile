import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../data/models/ice_server.dart';
import '../native/android_screen_share.dart';
import '../voice_call_log.dart';
import 'ice_candidate_stats.dart';

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
    required this.onLocalScreenChanged,
    required this.onRemoteScreenChanged,
  });

  final VoiceSignalSender sendSignal;
  final void Function() onConnected;
  final void Function(String reason) onFailed;
  final void Function(bool sharing) onLocalScreenChanged;
  final void Function(MediaStream? stream) onRemoteScreenChanged;

  RTCPeerConnection? _peer;
  MediaStream? _localStream;
  MediaStream? _screenStream;
  MediaStream? _remoteScreenStream;
  RTCRtpSender? _screenSender;
  final List<MediaStream> _remoteStreams = [];
  final List<RTCIceCandidate> _pendingCandidates = [];
  final IceCandidateStats _localCandidates = IceCandidateStats();
  bool _remoteDescriptionSet = false;
  bool _disposed = false;
  bool _connected = false;
  bool _answerReceived = false;
  Timer? _disconnectTimer;

  bool get ready => _peer != null && _localStream != null;

  bool get hasRemoteDescription => _remoteDescriptionSet;

  bool get answerReceived => _answerReceived;

  Future<void> prepare({required List<IceServer> iceServers}) async {
    if (_disposed) throw StateError('Voice peer engine is disposed');
    if (ready) return;

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

    await Helper.setAndroidAudioConfiguration(
      AndroidAudioConfiguration(
        manageAudioFocus: true,
        androidAudioMode: AndroidAudioMode.inCommunication,
        androidAudioFocusMode: AndroidAudioFocusMode.gain,
        androidAudioStreamType: AndroidAudioStreamType.voiceCall,
        androidAudioAttributesUsageType:
            AndroidAudioAttributesUsageType.voiceCommunication,
        androidAudioAttributesContentType:
            AndroidAudioAttributesContentType.speech,
        // Some Android devices otherwise leave a WebRTC call on a stale route.
        forceHandleAudioRouting: true,
      ),
    );
    await _ensureAudioSessionIfNeeded();
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    });
    _localStream = stream;

    final peer = await createPeerConnection({
      'iceServers': iceServers.map((server) => server.toWebRtcJson()).toList(),
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
      if (kForceRelayTransport) 'iceTransportPolicy': 'relay',
    });
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
        onFailed(_failureReason());
      }
    };
    peer.onConnectionState = _handleConnectionState;
    peer.onTrack = (event) {
      if (_disposed) return;
      if (event.track.kind == 'video') {
        final remote = event.streams.isNotEmpty ? event.streams.first : null;
        if (remote == null) return;
        _remoteScreenStream = remote;
        onRemoteScreenChanged(remote);
        event.track.onEnded = () {
          if (_disposed || _remoteScreenStream != remote) return;
          _remoteScreenStream = null;
          onRemoteScreenChanged(null);
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
      await peer.addTrack(track, stream);
    }
    // Start on speaker so a newly connected call is audible immediately.
    // The in-call Speaker button can still switch to the earpiece.
    await Helper.setSpeakerphoneOn(true);
  }

  Future<void> createAndSendOffer({bool renegotiate = false}) async {
    final peer = _requirePeer();
    if (!renegotiate) {
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
        if (!_sdpSendsVideo(sdp) && _remoteScreenStream != null) {
          _remoteScreenStream = null;
          onRemoteScreenChanged(null);
        }
        final peer = _requirePeer();
        await peer.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
        _remoteDescriptionSet = true;
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
        _disconnectTimer?.cancel();
        unawaited(_ensureAudioSessionIfNeeded());
        if (!_connected) {
          _connected = true;
          onConnected();
          // One-shot pair snapshot, then a 5s follow-up to confirm media flow.
          unawaited(logSelectedPair());
          Timer(const Duration(seconds: 5), () => unawaited(logMediaFlow()));
        }
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        onFailed(_failureReason());
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        _disconnectTimer?.cancel();
        _disconnectTimer = Timer(const Duration(seconds: 12), () {
          if (!_disposed) onFailed('peer_connection_disconnected');
        });
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
      case RTCPeerConnectionState.RTCPeerConnectionStateNew:
      case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
        break;
    }
  }

  /// Distinguishes "the connection dropped" from "no route could ever exist".
  String _failureReason() =>
      _localCandidates.lanOnly ? 'ice_no_relay' : 'peer_connection_failed';

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

  Future<void> setSpeaker(bool enabled) => Helper.setSpeakerphoneOn(enabled);

  Future<void> startScreenShare() async {
    if (_screenStream != null) return;
    final peer = _requirePeer();
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
      _screenStream = stream;
      _screenSender = await peer.addTrack(track, stream);
      onLocalScreenChanged(true);
      track.onEnded = () => unawaited(stopScreenShare());
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
    if (renegotiate && peer != null && !_disposed) await _renegotiate();
  }

  Future<void> _renegotiate() async {
    final peer = _requirePeer();
    final offer = await peer.createOffer({
      'mandatory': {'OfferToReceiveAudio': true, 'OfferToReceiveVideo': true},
    });
    await peer.setLocalDescription(offer);
    final sent = await sendSignal({'kind': 'offer', 'sdp': offer.sdp});
    if (!sent) throw StateError('signaling_unavailable');
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
    _disconnectTimer?.cancel();
    await stopScreenShare(renegotiate: false);
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
  }
}
