import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device_model.dart';
import '../services/discovery_service.dart';
import 'local_share_providers.dart';

/// Provider for tracking discovered devices on the local network.
///
/// Reads [currentLocalDeviceProvider] lazily (via `ref.read` per action)
/// rather than watching it, so the notifier — and the devices it has
/// already accumulated — survives the device alias changing (e.g. once the
/// signed-in user's profile name finishes loading).
final nearbyDevicesProvider =
    StateNotifierProvider<NearbyDevicesNotifier, Map<String, LocalDevice>>((
      ref,
    ) {
      return NearbyDevicesNotifier(ref);
    });

/// How long a peer can go unseen before we actively re-probe it.
const _staleAfter = Duration(seconds: 12);

class NearbyDevicesNotifier extends StateNotifier<Map<String, LocalDevice>> {
  final Ref _ref;
  StreamSubscription<LocalDevice>? _subscription;
  Timer? _heartbeatTimer;
  Timer? _pruneTimer;
  final Map<String, DateTime> _lastSeen = {};

  NearbyDevicesNotifier(this._ref) : super({});

  LocalDiscoveryService get _discoveryService =>
      _ref.read(localDiscoveryServiceProvider);
  LocalDevice get _currentDevice => _ref.read(currentLocalDeviceProvider);

  /// A peer without a fingerprint (non-AbabilX LocalSend client) is keyed by
  /// address instead of collapsing every such peer onto one shared `''` key.
  static String _keyFor(LocalDevice device) => device.fingerprint.isNotEmpty
      ? device.fingerprint
      : '${device.ip}:${device.port}';

  /// Starts listening for UDP Multicast discovery pings and announces
  /// presence, then keeps the peer list fresh with a periodic re-announce
  /// and a liveness sweep of anything that's gone quiet.
  Future<void> startDiscovery() async {
    await _discoveryService.startMulticastListener(
      currentDevice: _currentDevice,
    );

    _subscription?.cancel();
    _subscription = _discoveryService.onDeviceDiscovered?.listen((device) {
      addDevice(device);
    });

    await _announceAndScan();

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _discoveryService.announce(currentDevice: _currentDevice);
    });

    _pruneTimer?.cancel();
    _pruneTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _pruneStale(),
    );
  }

  Future<void> _announceAndScan() async {
    await _discoveryService.announce(currentDevice: _currentDevice);
    unawaited(
      _discoveryService.scanSubnet(
        currentDevice: _currentDevice,
        onFound: addDevice,
      ),
    );
  }

  /// Re-announces and rescans without restarting the multicast listener —
  /// used for a manual pull-to-refresh and after the app resumes from
  /// background (Wi-Fi may have changed while backgrounded).
  Future<void> refresh() => _announceAndScan();

  void addDevice(LocalDevice device) {
    if (device.fingerprint == _currentDevice.fingerprint) return;
    final key = _keyFor(device);
    _lastSeen[key] = DateTime.now();

    // A peer that relaunched keeps the same ip:port but mints a new
    // fingerprint — drop the stale entry so it doesn't linger as a ghost
    // duplicate of the same physical device.
    final next = {...state};
    final staleKey = next.keys.firstWhere(
      (k) =>
          k != key && next[k]!.ip == device.ip && next[k]!.port == device.port,
      orElse: () => '',
    );
    if (staleKey.isNotEmpty) {
      next.remove(staleKey);
      _lastSeen.remove(staleKey);
    }
    next[key] = device;
    state = next;
  }

  /// Re-probes peers that haven't announced recently; evicts ones that no
  /// longer answer instead of leaving a stale tile forever.
  Future<void> _pruneStale() async {
    final now = DateTime.now();
    final staleKeys = _lastSeen.entries
        .where((e) => now.difference(e.value) > _staleAfter)
        .map((e) => e.key)
        .toList();
    if (staleKeys.isEmpty) return;

    for (final key in staleKeys) {
      final device = state[key];
      if (device == null) {
        _lastSeen.remove(key);
        continue;
      }
      final refreshed = await _discoveryService.fetchDeviceInfo(
        ip: device.ip,
        port: device.port,
        currentDevice: _currentDevice,
      );
      if (refreshed == null) {
        // Unreachable — drop it. If it's actually alive under a new
        // fingerprint, addDevice's ip:port dedup replaces this entry once
        // its own announce/scan hit arrives.
        state = {...state}..remove(key);
        _lastSeen.remove(key);
      }
    }
  }

  void clear() {
    state = {};
    _lastSeen.clear();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _heartbeatTimer?.cancel();
    _pruneTimer?.cancel();
    super.dispose();
  }
}
