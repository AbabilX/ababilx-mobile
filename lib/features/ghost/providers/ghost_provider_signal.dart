part of 'ghost_provider.dart';

/// Socket events and sealed signalling.
mixin _GhostSignal on _GhostBase {
  void _onEvent(Map<String, dynamic> ev) {
    final type = ev['type'];
    if (type is! String || !type.startsWith('ghost.')) return;
    final raw = ev['ghost'];
    final session = raw is Map
        ? GhostSession.fromJson(Map<String, dynamic>.from(raw))
        : null;
    final id = session?.id ?? ev['id'] as String? ?? '';
    switch (type) {
      case 'ghost.invite':
        if (session != null) _onInvite(session);
      case 'ghost.accepted':
        _onAccepted(id);
      case 'ghost.ended':
        _onEnded(id, ev['reason'] as String? ?? GhostEndReason.leave);
      case 'ghost.signal':
        _onSignal(id, ev['from_user_id'] as String? ?? '', ev['ghost_signal']);
    }
  }

  bool _isMine(String id) => id.isNotEmpty && state.session?.id == id;

  void _onInvite(GhostSession session) {
    // One Ghost Chat at a time; the server refuses a second one anyway, and
    // a replayed invite for the session already on screen changes nothing.
    // The server addresses invites to the invitee alone; the id check only
    // guards a stale socket, and must not drop the invite replayed on a cold
    // start before the profile has loaded.
    final self = _selfId;
    if (state.inSession || (self.isNotEmpty && session.inviteeId != self)) {
      return;
    }
    if (session.expiresAt?.isBefore(DateTime.now()) ?? false) return;
    state = GhostState(
      phase: GhostPhase.invited,
      session: session,
      conversationId: session.conversationId,
      peerName: session.inviterName,
      peerAvatarUrl: session.inviterAvatarUrl,
    );
    final left =
        session.expiresAt?.difference(DateTime.now()) ?? ghostInviteWindow;
    _inviteTimer = Timer(left, () {
      if (state.phase == GhostPhase.invited) {
        _teardown();
        state = const GhostState();
      }
    });
  }

  void _onAccepted(String id) {
    if (!_isMine(id)) return;
    switch (state.phase) {
      case GhostPhase.inviting:
        // The peer joined: the inviter is the only side that offers.
        _inviteTimer?.cancel();
        state = state.copyWith(phase: GhostPhase.connecting);
        _connectTimer = Timer(
          ghostConnectTimeout,
          () => _lost('connect_timeout'),
        );
        unawaited(_whenPrepared(() => _peer?.offer()));
      case GhostPhase.invited:
        // Another of this account's devices joined. This one just stops.
        _teardown();
        state = const GhostState();
      default:
    }
  }

  void _onEnded(String id, String reason) {
    if (!_isMine(id)) return;
    if (state.phase == GhostPhase.invited) {
      _teardown();
      state = const GhostState();
      return;
    }
    if (state.inSession) _finish(reason, byMe: false, notifyServer: false);
  }

  void _onSignal(String id, String from, Object? raw) {
    final session = state.session;
    if (!_isMine(id) || session == null || raw is! Map) return;
    if (from != session.otherUserId(_selfId)) return;
    final kind = raw['kind'] as String? ?? '';
    final ready = _ready.future;
    _signalsIn = _signalsIn
        .then((_) async {
          await ready;
          Map<String, dynamic>? payload;
          if (kind != 'restart') {
            try {
              final clear = await _vault.openGhostSignal(
                conversationId: session.conversationId,
                sessionId: session.id,
                senderId: from,
                currentUserId: _selfId,
                keyVersion: session.keyVersion,
                signal: SealedGhostSignal(
                  sealed: raw['sealed'] as String? ?? '',
                  nonce: raw['nonce'] as String? ?? '',
                ),
              );
              payload = Map<String, dynamic>.from(jsonDecode(clear) as Map);
            } catch (_) {
              // Did not open: tampered, or not from the key both phones hold.
              // Never hand it to the peer connection.
              return;
            }
          }
          try {
            await _peer?.handleSignal(kind, payload);
          } catch (_) {
            _lost('signal_error');
          }
        })
        .catchError((_) {});
  }

  /// Seals and sends in order: an offer must never overtake its candidates,
  /// and sealing is async.
  @override
  void _sendSignal(String kind, Map<String, dynamic>? payload) {
    final session = state.session;
    if (session == null) return;
    _signalsOut = _signalsOut
        .then((_) async {
          final signal = <String, dynamic>{'kind': kind};
          if (payload != null) {
            final sealed = await _vault.sealGhostSignal(
              conversationId: session.conversationId,
              sessionId: session.id,
              senderId: _selfId,
              keyVersion: session.keyVersion,
              payload: jsonEncode(payload),
            );
            signal['sealed'] = sealed.sealed;
            signal['nonce'] = sealed.nonce;
          }
          await _ws.sendWhenConnected({
            'type': 'ghost.signal',
            'session_id': session.id,
            'ghost_signal': signal,
          });
        })
        .catchError((_) {});
  }

  Future<void> _whenPrepared(Future<void>? Function() action) async {
    try {
      await _ready.future;
      await action();
    } catch (_) {
      _lost('offer_failed');
    }
  }
}
