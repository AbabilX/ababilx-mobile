part of 'ghost_provider.dart';

/// The peer connection's life: connect, stay alive, recover a drop — and give
/// up after [ghostLostGrace], which burns.
///
/// ICE notices a dead path only after several seconds of failed consent
/// checks, so on its own a 5 s rule would really be ~10 s. Both phones also
/// ping over the channel every [ghostPingEvery]; [ghostLostGrace] of silence
/// burns, and the offline phone's own watchdog burns it there too.
mixin _GhostLink on _GhostBase {
  Future<void> _startPeer({required bool isOfferer}) async {
    final ready = _ready;
    final peer = GhostPeer(
      isOfferer: isOfferer,
      onSignal: _sendSignal,
      onOpen: _onOpen,
      onTrouble: _onTrouble,
      onHealthy: _onHealthy,
      onText: _onText,
      onBinary: _onBinary,
    );
    _peer = peer;
    _sender = GhostFileSender(() => peer.channel!);
    try {
      await peer.prepare(_iceServers);
      if (!ready.isCompleted) ready.complete();
    } catch (e) {
      if (!ready.isCompleted) ready.completeError(e);
      _lost('prepare_failed');
    }
  }

  void _onOpen() {
    _connectTimer?.cancel();
    _lostTimer?.cancel();
    if (state.phase == GhostPhase.connecting ||
        state.phase == GhostPhase.reconnecting) {
      state = state.copyWith(phase: GhostPhase.live);
    }
    _heartbeat ??= Timer.periodic(const Duration(seconds: 30), (_) {
      final id = state.session?.id;
      if (id != null) unawaited(_api.heartbeat(id).catchError((_) {}));
    });
    _pingTimer ??= Timer.periodic(ghostPingEvery, (_) => _pingTick());
  }

  void _pingTick() {
    final silent = _sinceHeard?.elapsed;
    if (silent != null && silent > ghostLostGrace) {
      _lost('silent');
      return;
    }
    final peer = _peer;
    if (peer == null || !peer.open) return;
    unawaited(
      peer.channel!
          .send(RTCDataChannelMessage(const GhostPingFrame().encode()))
          .catchError((_) {}),
    );
  }

  @override
  void _heard({required bool ping}) {
    final watch = _sinceHeard;
    if (watch != null) {
      watch.reset();
    } else if (ping) {
      _sinceHeard = Stopwatch()..start();
    }
  }

  void _onHealthy() {
    // A path that comes back under a closed channel recovers nothing.
    if (!(_peer?.open ?? false)) return;
    _lostTimer?.cancel();
    _lostTimer = null;
    if (state.phase == GhostPhase.reconnecting) {
      state = state.copyWith(phase: GhostPhase.live);
    }
  }

  /// A drop mid-session: show it, try to recover, and burn if it lasts.
  /// Before the channel ever opened the connect timeout owns the decision.
  void _onTrouble(String why) {
    if (state.phase != GhostPhase.live &&
        state.phase != GhostPhase.reconnecting) {
      return;
    }
    if (why == 'channel_closed') {
      // A channel only closes when the other phone closed it or died; ICE
      // cannot bring back a closed SCTP association. The close can land a
      // beat before that phone's own `burn` / `leave` frame or `ghost.ended`
      // is processed, so wait briefly to name the ending correctly.
      _lostTimer?.cancel();
      _lostTimer = Timer(const Duration(seconds: 2), () => _lost(why));
      return;
    }
    state = state.copyWith(phase: GhostPhase.reconnecting, peerTyping: false);
    _lostTimer ??= Timer(ghostLostGrace, () => _lost(why));
    unawaited(_retryUntilBack());
  }

  Future<void> _retryUntilBack() async {
    while (state.phase == GhostPhase.reconnecting && _lostTimer != null) {
      try {
        await _peer?.restart();
      } catch (_) {}
      await Future<void>.delayed(const Duration(seconds: 5));
    }
  }

  @override
  void _lost(String why) {
    if (!state.inSession) return;
    _finish(GhostEndReason.lost, byMe: true, notifyServer: true);
  }

  void _noAnswer() {
    if (state.phase != GhostPhase.inviting) return;
    _finish(GhostLocalReason.noAnswer, byMe: true, notifyServer: true);
  }

  /// Leaving the app ends the chat, but not instantly: a file picker or a
  /// glance at a notification also sends the app to the background, and
  /// burning on those would make the feature unusable, so it gets
  /// [ghostBackgroundGrace] — the app is still online and pinging while
  /// paused, so the 5 s offline rule does not apply. [AppLifecycleState.detached] is the process going
  /// away — no grace, the peer is told now while a frame can still be sent.
  void onAppLifecycle(AppLifecycleState lifecycle) {
    if (!state.inSession || state.phase == GhostPhase.invited) return;
    switch (lifecycle) {
      case AppLifecycleState.resumed:
        _backgroundTimer?.cancel();
        _backgroundTimer = null;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _backgroundTimer ??= Timer(ghostBackgroundGrace, () {
          _backgroundTimer = null;
          if (state.inSession) {
            _finish(GhostEndReason.leave, byMe: true, notifyServer: true);
          }
        });
      case AppLifecycleState.detached:
        _finish(GhostEndReason.leave, byMe: true, notifyServer: true);
      case AppLifecycleState.inactive:
    }
  }
}
