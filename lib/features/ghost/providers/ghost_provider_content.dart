part of 'ghost_provider.dart';

/// Messages and files, both directions. RAM only.
mixin _GhostContent on _GhostBase {
  static const _uuid = Uuid();

  Future<bool> sendText(String text) async {
    final body = text.trim();
    final peer = _peer;
    if (!state.canSend || peer == null || body.isEmpty) return false;
    if (body.length > maxBodyChars) {
      state = state.copyWith(error: 'ghost_message_too_long');
      return false;
    }
    final frame = GhostTextFrame(
      id: _uuid.v4(),
      body: body,
      at: DateTime.now().millisecondsSinceEpoch,
    );
    try {
      await peer.channel!.send(RTCDataChannelMessage(frame.encode()));
    } catch (_) {
      return false;
    }
    _typingSentAt = null;
    _append(
      GhostItem(id: frame.id, fromMe: true, at: DateTime.now(), body: body),
    );
    return true;
  }

  Future<void> sendFile(
    String name,
    String mime,
    Uint8List bytes, {
    GhostItemRules rules = GhostItemRules.none,
  }) async {
    final sender = _sender;
    if (!state.canSend || sender == null) {
      bytes.fillRange(0, bytes.length, 0);
      return;
    }
    if (bytes.length > maxGhostFileBytes) {
      bytes.fillRange(0, bytes.length, 0);
      state = state.copyWith(error: 'ghost_file_too_large');
      return;
    }
    final header = GhostFileHeader(
      id: _uuid.v4(),
      name: safeGhostFileName(name),
      mime: mime,
      size: bytes.length,
      at: DateTime.now().millisecondsSinceEpoch,
      rules: mime.startsWith('image/')
          ? rules
          : GhostItemRules(allowSave: rules.allowSave),
    );
    _append(
      GhostItem(
        id: header.id,
        fromMe: true,
        at: DateTime.now(),
        fileName: header.name,
        mime: mime,
        size: header.size,
        bytes: bytes,
        rules: header.rules,
      ),
    );
    final ok = await sender.send(
      header,
      bytes,
      onProgress: (sent) =>
          _patch(header.id, (i) => i.copyWith(transferred: sent)),
    );
    if (!ok) _patch(header.id, (i) => i.copyWith(failed: true));
  }

  /// Draft changed. One `typing` frame per 3 s, the chat's own cadence.
  void onDraftChanged(String text) {
    final peer = _peer;
    if (!state.canSend || peer == null) return;
    final now = DateTime.now();
    final typing = text.trim().isNotEmpty;
    final last = _typingSentAt;
    if (typing && last != null && now.difference(last).inSeconds < 3) return;
    if (!typing && last == null) return;
    _typingSentAt = typing ? now : null;
    unawaited(
      peer.channel!
          .send(RTCDataChannelMessage(GhostTypingFrame(on: typing).encode()))
          .catchError((_) {}),
    );
  }

  @override
  void _onText(String raw) {
    switch (GhostFrame.decode(raw)) {
      case GhostTextFrame(:final id, :final body):
        _typingExpiry?.cancel();
        state = state.copyWith(peerTyping: false);
        _append(
          GhostItem(id: id, fromMe: false, at: DateTime.now(), body: body),
        );
      case final GhostFileHeader header:
        if (!_assembler.begin(header)) return;
        _append(
          GhostItem(
            id: header.id,
            fromMe: false,
            at: DateTime.now(),
            fileName: header.name,
            mime: header.mime,
            size: header.size,
            rules: header.rules,
          ),
        );
      case GhostTypingFrame(:final on):
        _typingExpiry?.cancel();
        state = state.copyWith(peerTyping: on);
        if (on) {
          _typingExpiry = Timer(const Duration(seconds: 5), () {
            state = state.copyWith(peerTyping: false);
          });
        }
      case GhostViewedFrame(:final id):
        _onPeerViewed(id);
      case GhostBurnFrame():
        _finish(GhostEndReason.burn, byMe: false, notifyServer: false);
      case GhostLeaveFrame():
        _finish(GhostEndReason.leave, byMe: false, notifyServer: false);
      case null:
    }
  }

  @override
  void _onBinary(Uint8List bytes) {
    final id = _assembler.current?.id;
    if (id == null) return;
    switch (_assembler.add(bytes)) {
      case GhostReceivedFile(:final bytes):
        _patch(id, (i) => i.copyWith(bytes: bytes, transferred: bytes.length));
      case GhostFileProgress(:final received):
        // Every chunk would rebuild the list 3000 times for a large file.
        if (received % (ghostChunkBytes * 32) == 0) {
          _patch(id, (i) => i.copyWith(transferred: received));
        }
      default:
        _patch(id, (i) => i.copyWith(failed: true));
    }
  }

  void _append(GhostItem item) {
    if (state.items.any((i) => i.id == item.id)) return;
    state = state.copyWith(items: [...state.items, item]);
  }

  void _patch(String id, GhostItem Function(GhostItem) change) {
    state = state.copyWith(
      items: [
        for (final item in state.items) item.id == id ? change(item) : item,
      ],
    );
  }
}
