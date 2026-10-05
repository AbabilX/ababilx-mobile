// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'dart:io';

import 'data/drift_share_store.dart';
import 'data/local_share_db.dart';
import 'data/share_device_queries.dart';
import 'data/share_thread_queries.dart';
import 'engine/client/share_client.dart';
import 'engine/client/share_endpoint.dart';
import 'engine/discovery/share_presence.dart';
import 'engine/protocol/share_peer.dart';
import 'engine/server/share_server.dart';
import 'engine/server/share_server_context.dart';
import 'engine/share_layout.dart';
import 'engine/share_progress.dart';
import 'engine/share_sender.dart';
import 'engine/store/share_records.dart';

/// Everything Local Share runs for one signed-in account: its database, the
/// receive server, discovery and the sender. Nothing here talks to the
/// AbabilX server.
class LocalShareEngine {
  LocalShareEngine._({
    required this.deviceId,
    required this.db,
    required this.layout,
    required String Function() name,
    required String? Function() accountId,
  }) : _name = name,
       _accountId = accountId,
       store = DriftShareStore(db),
       queries = ShareThreadQueries(db);

  /// Opens the account's database and file folder. Nothing listens yet.
  static Future<LocalShareEngine> open({
    required String userId,
    required String deviceId,
    required String Function() name,
    required String? Function() accountId,
    required Future<bool> Function(SharePeer peer) askPair,
    void Function(String deviceId, String messageId)? onIncoming,
  }) async {
    final root = await localShareRoot(userId);
    final engine = LocalShareEngine._(
      deviceId: deviceId,
      db: LocalShareDb(userId),
      layout: ShareLayout('${root.path}/files'),
      name: name,
      accountId: accountId,
    );
    engine._wire(askPair, onIncoming);
    return engine;
  }

  final String deviceId;
  final LocalShareDb db;
  final ShareLayout layout;
  final DriftShareStore store;
  final ShareThreadQueries queries;
  final progress = ShareProgressHub();
  final String Function() _name;
  final String? Function() _accountId;

  late final ShareClient client = ShareClient(progress);
  late final ShareServer server;
  late final SharePresence presence;
  late final ShareSender sender;
  StreamSubscription<Map<String, SharePeer>>? _peersSub;
  int _port = shareDefaultPort;
  bool _started = false;

  /// Called with a device id each time that device comes into range.
  void Function(String deviceId)? onDeviceNearby;

  bool get started => _started;

  SharePeer self() => SharePeer(
    deviceId: deviceId,
    name: _name(),
    deviceType: Platform.isAndroid || Platform.isIOS ? 'mobile' : 'desktop',
    port: _port,
    userId: _accountId(),
  );

  void _wire(
    Future<bool> Function(SharePeer peer) askPair,
    void Function(String deviceId, String messageId)? onIncoming,
  ) {
    server = ShareServer(
      ShareServerContext(
        store: store,
        layout: layout,
        progress: progress,
        self: self,
        onPairRequest: askPair,
        onMessage: onIncoming,
      ),
    );
    presence = SharePresence(
      self: self,
      client: client,
      known: queries.knownAddresses,
    );
    sender = ShareSender(
      store: store,
      client: client,
      progress: progress,
      endpoint: endpoint,
    );
  }

  /// Binds the server and starts announcing.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _port = await server.start();
    final seen = <String>{};
    _peersSub = presence.changes.listen((peers) {
      for (final peer in peers.values) {
        unawaited(queries.touch(peer));
        if (seen.add(peer.deviceId)) onDeviceNearby?.call(peer.deviceId);
      }
      seen.removeWhere((id) => !peers.containsKey(id));
    });
    await presence.start();
  }

  /// The app left the screen: stop announcing and listening for peers. The
  /// server stays bound, so a transfer already running keeps going.
  Future<void> pauseDiscovery() => presence.stop();

  Future<void> resumeDiscovery() async {
    if (_started) await presence.start();
  }

  /// The Wi-Fi changed: every socket is bound to an address that is gone.
  Future<void> networkChanged() async {
    if (!_started) return;
    await presence.stop();
    await presence.start();
  }

  /// Where a paired device is right now; null when it is away or unpaired.
  Future<ShareEndpoint?> endpoint(String peerId) async {
    final peer = presence.peers[peerId];
    final device = await store.device(peerId);
    final token = device?.pairToken;
    if (peer == null || device == null || device.blocked || token == null) {
      return null;
    }
    return ShareEndpoint(
      ip: peer.ip,
      port: peer.port,
      token: token,
      selfDeviceId: deviceId,
    );
  }

  /// Asks [peer]'s user to accept this device. Null on Accept, otherwise the
  /// reason (`declined`, `blocked`, `timeout`, `busy`, `unreachable`).
  Future<String?> pair(SharePeer peer) async {
    final result = await client.pair(peer.ip, peer.port, self());
    final token = result.token;
    if (token == null) return result.error ?? 'unreachable';
    final known = await store.device(peer.deviceId);
    await store.saveDevice(
      ShareDeviceRecord(
        deviceId: peer.deviceId,
        name: peer.name,
        deviceType: peer.deviceType,
        userId: peer.userId,
        pairToken: token,
        blocked: known?.blocked ?? false,
        lastIp: peer.ip,
        lastPort: peer.port,
        lastSeenMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    return null;
  }

  Future<void> dispose() async {
    _started = false;
    await _peersSub?.cancel();
    await presence.dispose();
    await server.stop();
    client.close();
    await progress.dispose();
    await db.close();
  }
}
