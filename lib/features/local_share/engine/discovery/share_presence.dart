import 'dart:async';

import '../client/share_client.dart';
import '../protocol/share_peer.dart';
import 'share_multicast.dart';
import 'share_sweep.dart';

typedef ShareAddress = ({String ip, int port});

/// Who is on the network right now.
///
/// An announce is answered by every listener, so two devices see each other
/// within one round trip instead of waiting for the other's next tick. A peer
/// that goes quiet is asked directly before it is dropped, and when multicast
/// finds nobody (routers with client isolation drop it) the /24 is swept.
class SharePresence {
  SharePresence({
    required this.self,
    required this.client,
    this.known,
    ShareMulticast? multicast,
  }) : _multicast = multicast ?? ShareMulticast();

  static const announceEvery = Duration(seconds: 5);
  static const staleAfter = Duration(seconds: 15);
  static const sweepIfAloneAfter = Duration(seconds: 3);

  final SharePeer Function() self;
  final ShareClient client;

  /// Last known addresses of devices with a thread — asked first, so someone
  /// you talk to shows up before a sweep would have found them.
  final Future<List<ShareAddress>> Function()? known;

  final ShareMulticast _multicast;
  final _peers = <String, SharePeer>{};
  final _seen = <String, DateTime>{};
  final _changes = StreamController<Map<String, SharePeer>>.broadcast();
  StreamSubscription<ShareDatagram>? _subscription;
  Timer? _heartbeat;
  Timer? _aloneTimer;
  bool _sweeping = false;

  Map<String, SharePeer> get peers => Map.unmodifiable(_peers);
  Stream<Map<String, SharePeer>> get changes => _changes.stream;
  bool get running => _heartbeat != null;

  Future<void> start() async {
    if (running) return;
    await _multicast.start();
    _subscription = _multicast.incoming.listen(_onDatagram);
    _heartbeat = Timer.periodic(announceEvery, (_) => _tick());
    _announce();
    unawaited(_probeKnown());
    _aloneTimer = Timer(sweepIfAloneAfter, () {
      if (_peers.isEmpty) unawaited(sweep());
    });
  }

  /// Stops everything that costs battery. Peers already found are forgotten:
  /// the network may be a different one when we come back.
  Future<void> stop() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    _aloneTimer?.cancel();
    await _subscription?.cancel();
    _subscription = null;
    await _multicast.stop();
    if (_peers.isNotEmpty) {
      _peers.clear();
      _seen.clear();
      _publish();
    }
  }

  /// Announce again, ask known devices, and sweep. For pull-to-refresh and a
  /// network change (after [stop] + [start]).
  Future<void> refresh() async {
    _announce();
    await _probeKnown();
    await sweep();
  }

  /// Adds a device by address (a scanned QR); null when nothing answers.
  Future<SharePeer?> probe(String ip, int port) async {
    final peer = await client.info(ip, port);
    if (peer != null) _add(peer);
    return peer;
  }

  Future<void> sweep() async {
    if (_sweeping) return;
    _sweeping = true;
    try {
      await sweepShareSubnets(
        client: client,
        localAddresses: _multicast.localAddresses,
        onFound: _add,
      );
    } finally {
      _sweeping = false;
    }
  }

  void _announce() => _multicast.broadcast(self().encode(announce: true));

  void _onDatagram(ShareDatagram datagram) {
    final peer = SharePeer.fromJson(datagram.json, ip: datagram.ip);
    if (peer == null) return;
    if (isShareAnnounce(datagram.json) && peer.deviceId != self().deviceId) {
      _multicast.reply(self().encode(announce: false), datagram.ip);
    }
    _add(peer);
  }

  void _add(SharePeer peer) {
    if (peer.deviceId == self().deviceId || peer.ip.isEmpty) return;
    _seen[peer.deviceId] = DateTime.now();
    // A reinstalled app keeps its address and mints a new id: drop the ghost.
    final ghosts = [
      for (final other in _peers.values)
        if (other.deviceId != peer.deviceId &&
            other.ip == peer.ip &&
            other.port == peer.port)
          other.deviceId,
    ];
    for (final ghost in ghosts) {
      _peers.remove(ghost);
      _seen.remove(ghost);
    }
    final before = _peers[peer.deviceId];
    _peers[peer.deviceId] = peer;
    if (ghosts.isNotEmpty || before == null || !_same(before, peer)) {
      _publish();
    }
  }

  Future<void> _tick() async {
    _announce();
    final now = DateTime.now();
    final quiet = [
      for (final entry in _seen.entries)
        if (now.difference(entry.value) > staleAfter) entry.key,
    ];
    for (final id in quiet) {
      final peer = _peers[id];
      if (peer == null) continue;
      final alive = await client.info(peer.ip, peer.port);
      if (alive != null && alive.deviceId == id) {
        _add(alive);
      } else if (_peers.remove(id) != null) {
        _seen.remove(id);
        _publish();
      }
    }
  }

  Future<void> _probeKnown() async {
    final addresses = await known?.call() ?? const <ShareAddress>[];
    await Future.wait([
      for (final a in addresses)
        if (a.ip.isNotEmpty && a.port > 0) probe(a.ip, a.port),
    ]);
  }

  void _publish() {
    if (!_changes.isClosed) _changes.add(peers);
  }

  static bool _same(SharePeer a, SharePeer b) =>
      a.name == b.name &&
      a.ip == b.ip &&
      a.port == b.port &&
      a.userId == b.userId &&
      a.deviceType == b.deviceType;

  Future<void> dispose() async {
    await stop();
    await _multicast.dispose();
    await _changes.close();
  }
}
