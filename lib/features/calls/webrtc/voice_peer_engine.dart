import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../data/models/ice_server.dart';
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

class VoicePeerEngine {
  VoicePeerEngine({
    required this.sendSignal,
    required this.onConnected,
    required this.onFailed,
  });

  final VoiceSignalSender sendSignal;
  final void Function() onConnected;
  final void Function(String reason) onFailed;

  RTCPeerConnection? _peer;
  MediaStream? _localStream;
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
    });
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
          reason: 'no srflx/relay — STUN/TURN unreachable, '
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
      if (_disposed || event.track.kind != 'audio') return;
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
        'mandatory': {
          'OfferToReceiveAudio': true,
          'OfferToReceiveVideo': false,
        },
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
        final peer = _requirePeer();
        await peer.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
        _remoteDescriptionSet = true;
        await _flushCandidates();
        final answer = await peer.createAnswer({
          'mandatory': {
            'OfferToReceiveAudio': true,
            'OfferToReceiveVideo': false,
          },
        });
        await peer.setLocalDescription(answer);
        final sent = await sendSignal({'kind': 'answer', 'sdp': answer.sdp});
        voiceCallLog(
          'signal.answer.send',
          reason: sent ? 'ok' : 'ws_unavailable',
        );
        if (!sent) onFailed('signaling_unavailable');
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
          await _requirePeer().addCandidate(parsed);
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
    final peer = _requirePeer();
    for (final candidate in _pendingCandidates) {
      await peer.addCandidate(candidate);
    }
    _pendingCandidates.clear();
  }

  Future<void> setMuted(bool muted) async {
    for (final track in _localStream?.getAudioTracks() ?? const []) {
      track.enabled = !muted;
      await Helper.setMicrophoneMute(muted, track);
    }
  }

  Future<void> setSpeaker(bool enabled) => Helper.setSpeakerphoneOn(enabled);

  RTCPeerConnection _requirePeer() {
    final peer = _peer;
    if (peer == null) throw StateError('Voice peer is not prepared');
    return peer;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _disconnectTimer?.cancel();
    for (final track in _localStream?.getTracks() ?? const []) {
      await track.stop();
    }
    await _localStream?.dispose();
    _localStream = null;
    _remoteStreams.clear();
    await _peer?.close();
    await _peer?.dispose();
    _peer = null;
    await Helper.clearAndroidCommunicationDevice();
  }
}
