part of 'ghost_provider.dart';

/// Every way a Ghost Chat ends, and the wipe they all share.
mixin _GhostEnd on _GhostBase {
  /// The fire button. Both phones wipe the instant it is pressed: this one
  /// immediately, the other on whichever arrives first — the frame over the
  /// data channel or `ghost.ended` over the socket.
  void burn() => _finish(GhostEndReason.burn, byMe: true, notifyServer: true);

  /// Back, or cancelling an invite. Leaving burns too; nothing survives it.
  void leave() => _finish(GhostEndReason.leave, byMe: true, notifyServer: true);

  @override
  void _finish(
    String reason, {
    required bool byMe,
    required bool notifyServer,
    String? error,
  }) {
    if (state.phase == GhostPhase.idle || state.phase == GhostPhase.ended) {
      return;
    }
    final session = state.session;
    final items = state.items;
    final wasPending =
        state.phase == GhostPhase.inviting || state.phase == GhostPhase.invited;

    // Say goodbye over the channel BEFORE it is torn down; the socket path
    // below is the backstop when the channel is already gone.
    final peer = _peer;
    _peer = null;
    if (byMe && peer != null && peer.open) {
      final frame = reason == GhostEndReason.burn
          ? const GhostBurnFrame()
          : const GhostLeaveFrame();
      unawaited(
        peer.channel!
            .send(RTCDataChannelMessage(frame.encode()))
            .timeout(const Duration(seconds: 2))
            .catchError((_) {})
            .whenComplete(peer.dispose),
      );
    } else {
      unawaited(peer?.dispose());
    }

    if (notifyServer && session != null) {
      final action = !wasPending
          ? 'end'
          : session.inviterId == _selfId
          ? 'cancel'
          : 'decline';
      unawaited(
        _api.finish(session.id, action, reason: reason).catchError((_) {}),
      );
    }

    _wipe(items);
    _teardown();
    state = GhostState(
      phase: GhostPhase.ended,
      conversationId: state.conversationId,
      peerName: state.peerName,
      peerAvatarUrl: state.peerAvatarUrl,
      endReason: reason,
      endedByMe: byMe,
      error: error,
    );
  }

  /// What "removed" means on this phone:
  ///
  /// - every file buffer, sent or received, is overwritten with zeros — the
  ///   bytes are not merely unreferenced and left for the collector;
  /// - decoded pictures are evicted from Flutter's image cache, which would
  ///   otherwise keep a full-resolution copy alive after the list is gone;
  /// - the temp files made only to open a document in another app are deleted.
  ///
  /// Message text is a Dart String, which cannot be overwritten in place; it
  /// becomes unreachable here and is collected like any other.
  void _wipe(List<GhostItem> items) {
    for (final item in items) {
      final bytes = item.bytes;
      if (bytes != null) bytes.fillRange(0, bytes.length, 0);
    }
    final images = PaintingBinding.instance.imageCache;
    images.clear();
    images.clearLiveImages();
    unawaited(GhostBlobs.clear());
    unawaited(GhostTempFiles.purge());
  }

  /// Timers, sender, assembler and signalling chains — everything but state.
  @override
  void _teardown() {
    for (final timer in [
      _inviteTimer,
      _connectTimer,
      _lostTimer,
      _heartbeat,
      _backgroundTimer,
      _typingExpiry,
    ]) {
      timer?.cancel();
    }
    _inviteTimer = _connectTimer = _lostTimer = _heartbeat = null;
    _backgroundTimer = _typingExpiry = null;
    _typingSentAt = null;
    _sender?.cancel();
    _sender = null;
    final peer = _peer;
    _peer = null;
    unawaited(peer?.dispose());
    _assembler.clear();
    _signalsOut = Future.value();
    _signalsIn = Future.value();
    if (!_ready.isCompleted) _ready.completeError(StateError('ghost ended'));
    _ready.future.ignore();
    _ready = Completer<void>();
    _iceServers = const [];
  }
}
