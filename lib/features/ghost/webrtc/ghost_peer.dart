import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../calls/data/models/ice_server.dart';

/// Hands one negotiation step to the signalling layer, which seals it.
typedef GhostSignalOut =
    void Function(String kind, Map<String, dynamic>? payload);

/// One peer connection carrying one data channel — no microphone, no camera,
/// no audio session. Everything Ghost Chat sends rides on [channel].
///
/// Negotiation follows the 1:1 call's rule: the INVITER is the only side that
/// ever creates an offer. flutter_webrtc has no SDP rollback, so glare cannot
/// be undone on a phone, only avoided; the invitee asks for a re-offer with a
/// payload-less `restart` instead of offering itself.
///
/// The channel is `negotiated` with a fixed id, so both sides create it before
/// the first offer and neither waits on `onDataChannel`.
class GhostPeer {
  GhostPeer({
    required this.isOfferer,
    required this.onSignal,
    required this.onOpen,
    required this.onTrouble,
    required this.onHealthy,
    required this.onText,
    required this.onBinary,
  });

  final bool isOfferer;
  final GhostSignalOut onSignal;
  final VoidCallback onOpen;
  final void Function(String reason) onTrouble;
  final VoidCallback onHealthy;
  final void Function(String text) onText;
  final void Function(Uint8List bytes) onBinary;

  RTCPeerConnection? _pc;
  RTCDataChannel? _channel;
  final _pendingIce = <RTCIceCandidate>[];
  bool _remoteSet = false;
  bool _disposed = false;

  RTCDataChannel? get channel => _channel;
  bool get open =>
      _channel?.state == RTCDataChannelState.RTCDataChannelOpen && !_disposed;

  Future<void> prepare(List<IceServer> iceServers) async {
    final pc = await createPeerConnection({
      'iceServers': [for (final s in iceServers) s.toWebRtcJson()],
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
    });
    if (_disposed) {
      await pc.close();
      return;
    }
    _pc = pc;
    pc.onIceCandidate = (c) {
      final value = c.candidate;
      if (_disposed || value == null || value.isEmpty) return;
      onSignal('ice', {
        'candidate': value,
        'sdp_mid': c.sdpMid ?? '',
        'sdp_mline_index': c.sdpMLineIndex,
      });
    };
    pc.onConnectionState = (state) {
      if (_disposed) return;
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          onHealthy();
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          onTrouble(state.name);
        default:
      }
    };
    final channel = await pc.createDataChannel(
      'ghost',
      RTCDataChannelInit()
        ..ordered = true
        ..negotiated = true
        ..id = 0,
    );
    _channel = channel;
    channel.onDataChannelState = (state) {
      if (_disposed) return;
      if (state == RTCDataChannelState.RTCDataChannelOpen) onOpen();
      if (state == RTCDataChannelState.RTCDataChannelClosed) {
        onTrouble('channel_closed');
      }
    };
    channel.onMessage = (message) {
      if (_disposed) return;
      message.isBinary ? onBinary(message.binary) : onText(message.text);
    };
  }

  /// Inviter only. [iceRestart] recovers a dropped path without a new session.
  Future<void> offer({bool iceRestart = false}) async {
    final pc = _pc;
    if (!isOfferer || pc == null || _disposed) return;
    final offer = await pc.createOffer({if (iceRestart) 'iceRestart': true});
    await pc.setLocalDescription(offer);
    onSignal('offer', {'sdp': offer.sdp, 'type': offer.type});
  }

  /// Asks for recovery from whichever side notices the drop first.
  Future<void> restart() async {
    if (isOfferer) return offer(iceRestart: true);
    onSignal('restart', null);
  }

  Future<void> handleSignal(String kind, Map<String, dynamic>? payload) async {
    final pc = _pc;
    if (pc == null || _disposed) return;
    switch (kind) {
      case 'offer' when !isOfferer:
        await pc.setRemoteDescription(
          RTCSessionDescription(payload?['sdp'] as String?, 'offer'),
        );
        await _remoteReady(pc);
        final answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);
        onSignal('answer', {'sdp': answer.sdp, 'type': answer.type});
      case 'answer' when isOfferer:
        final state = await pc.getSignalingState();
        if (state != RTCSignalingState.RTCSignalingStateHaveLocalOffer) return;
        await pc.setRemoteDescription(
          RTCSessionDescription(payload?['sdp'] as String?, 'answer'),
        );
        await _remoteReady(pc);
      case 'ice':
        final candidate = RTCIceCandidate(
          payload?['candidate'] as String?,
          payload?['sdp_mid'] as String?,
          (payload?['sdp_mline_index'] as num?)?.toInt(),
        );
        if (!_remoteSet) {
          _pendingIce.add(candidate);
        } else {
          await pc.addCandidate(candidate);
        }
      case 'restart' when isOfferer:
        await offer(iceRestart: true);
    }
  }

  Future<void> _remoteReady(RTCPeerConnection pc) async {
    _remoteSet = true;
    final queued = List.of(_pendingIce);
    _pendingIce.clear();
    for (final candidate in queued) {
      await pc.addCandidate(candidate);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _pendingIce.clear();
    final channel = _channel, pc = _pc;
    _channel = null;
    _pc = null;
    try {
      await channel?.close();
    } catch (_) {}
    try {
      await pc?.close();
      await pc?.dispose();
    } catch (_) {}
  }
}
