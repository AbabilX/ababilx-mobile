part of 'ghost_provider.dart';

/// Timed photos: the moment one is gone, on both phones.
///
/// The receiver calls [viewed] when its viewer closes (view once) or the
/// countdown runs out; the sender hears it as a `viewed` frame. Both then do
/// the same thing the burn does, for that one photo: zero the bytes, evict the
/// decoded picture, keep only the placeholder.
mixin _GhostView on _GhostBase, _GhostContent {
  /// The receiver's viewer closed. Idempotent: the viewer calls it from
  /// dispose, which also runs after the timer already closed it.
  void viewed(String id) {
    final item = _item(id);
    if (item == null || item.fromMe || !item.timed || item.expired) return;
    _expire(item);
    final peer = _peer;
    if (peer == null || !peer.open) return;
    unawaited(
      peer.channel!
          .send(RTCDataChannelMessage(GhostViewedFrame(id: id).encode()))
          .catchError((_) {}),
    );
  }

  /// A peer can only ever expire the SENDER's own timed photo this way, so a
  /// forged id costs nothing.
  @override
  void _onPeerViewed(String id) {
    final item = _item(id);
    if (item == null || !item.fromMe || !item.timed || item.expired) return;
    _expire(item);
  }

  /// Remembers the send preview's choice for the next photo or file.
  void rememberRules(GhostItemRules rules) =>
      state = state.copyWith(lastRules: rules);

  GhostItem? _item(String id) {
    for (final item in state.items) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _expire(GhostItem item) {
    final bytes = item.bytes;
    _patch(item.id, (i) => i.copyWith(expired: true));
    // Zeroed only after the list stops pointing at it, so no frame is ever
    // decoded from a half-cleared buffer.
    if (bytes != null) bytes.fillRange(0, bytes.length, 0);
    final images = PaintingBinding.instance.imageCache;
    images.clear();
    images.clearLiveImages();
  }
}
