import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../calls/data/models/ice_server.dart';

/// The phone's half of a live history link: one peer connection, one
/// negotiated data channel ("history", id 0), and this side is the ONLY
/// offerer — flutter_webrtc has no SDP rollback (the Ghost Chat rule). The
/// browser answers, and asks for a fresh offer when it needs one.
class LivePeer {
  LivePeer({
    required this.onSignal,
    required this.onOpen,
    required this.onClosed,
    required this.onBinary,
  });

  final void Function(String kind, Map<String, dynamic> payload) onSignal;
  final VoidCallback onOpen;
  final VoidCallback onClosed;
  final void Function(Uint8List bytes) onBinary;

  RTCPeerConnection? _pc;
  RTCDataChannel? _channel;
  final _pendingIce = <RTCIceCandidate>[];
  bool _remoteSet = false;
  bool _disposed = false;

  bool get open =>
      !_disposed && _channel?.state == RTCDataChannelState.RTCDataChannelOpen;

  RTCDataChannel? get channel => _channel;

  /// Builds the connection and sends the offer.
  Future<void> start(List<IceServer> iceServers) async {
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
        'sdpMid': c.sdpMid ?? '0',
        'sdpMLineIndex': c.sdpMLineIndex ?? 0,
      });
    };
    pc.onConnectionState = (state) {
      if (_disposed) return;
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        onClosed();
      }
    };
    final channel = await pc.createDataChannel(
      'history',
      RTCDataChannelInit()
        ..ordered = true
        ..negotiated = true
        ..id = 0,
    );
    _channel = channel;
    channel.onDataChannelState = (state) {
      if (_disposed) return;
      if (state == RTCDataChannelState.RTCDataChannelOpen) onOpen();
      if (state == RTCDataChannelState.RTCDataChannelClosed) onClosed();
    };
    channel.onMessage = (message) {
      if (!_disposed && message.isBinary) onBinary(message.binary);
    };
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    onSignal('offer', {'type': offer.type, 'sdp': offer.sdp});
  }

  Future<void> handleSignal(String kind, Map<String, dynamic> payload) async {
    final pc = _pc;
    if (pc == null || _disposed) return;
    switch (kind) {
      case 'answer':
        final state = await pc.getSignalingState();
        if (state != RTCSignalingState.RTCSignalingStateHaveLocalOffer) return;
        await pc.setRemoteDescription(
          RTCSessionDescription(payload['sdp'] as String?, 'answer'),
        );
        _remoteSet = true;
        final queued = List.of(_pendingIce);
        _pendingIce.clear();
        for (final candidate in queued) {
          await pc.addCandidate(candidate);
        }
      case 'ice':
        final candidate = RTCIceCandidate(
          payload['candidate'] as String?,
          payload['sdpMid'] as String?,
          (payload['sdpMLineIndex'] as num?)?.toInt(),
        );
        if (_remoteSet) {
          await pc.addCandidate(candidate);
        } else {
          _pendingIce.add(candidate);
        }
    }
  }

  Future<void> send(Uint8List piece) async {
    final channel = _channel;
    if (channel == null || !open) throw StateError('channel closed');
    await channel.send(RTCDataChannelMessage.fromBinary(piece));
  }

  Future<int> buffered() async => await _channel?.getBufferedAmount() ?? 0;

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
