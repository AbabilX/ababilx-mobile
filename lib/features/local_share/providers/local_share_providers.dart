import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/providers/profile_provider.dart';
import '../models/device_model.dart';
import '../models/file_dto.dart';
import '../models/session_state.dart';
import '../services/discovery_service.dart';
import '../services/local_ip_service.dart';
import '../services/local_server_service.dart';
import '../services/transfer_client_service.dart';

/// Stable per-session identifier — computed once and never recomputed, so a
/// device's identity on the LAN doesn't shift while [currentLocalDeviceProvider]
/// rebuilds for other reasons (e.g. profile name loading in).
final _deviceFingerprintProvider = Provider<String>((ref) {
  return 'ababilx_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
});

/// Provider for current device identity information (Mobile).
/// Alias mirrors the signed-in user's profile name (falls back to a generic
/// platform label while the profile is still loading).
final currentLocalDeviceProvider = Provider<LocalDevice>((ref) {
  final platformName = Platform.isAndroid ? 'Android' : 'iOS';
  final profileName = ref.watch(profileProvider).valueOrNull?.name;
  final alias = (profileName != null && profileName.isNotEmpty)
      ? profileName
      : 'AbabilX ($platformName)';

  return LocalDevice(
    alias: alias,
    version: '2.1',
    deviceModel: platformName,
    deviceType: 'mobile',
    fingerprint: ref.watch(_deviceFingerprintProvider),
    ip: '127.0.0.1',
    port: 12045,
    protocol: 'http',
    download: true,
  );
});

/// Service providers
final localIpServiceProvider = Provider((ref) => LocalIpService());
final localDiscoveryServiceProvider = Provider((ref) => LocalDiscoveryService());
final localServerServiceProvider = Provider((ref) => LocalServerService());
final localTransferClientServiceProvider = Provider((ref) => LocalTransferClientService());

/// Provider for tracking discovered devices on the local network.
///
/// Reads [currentLocalDeviceProvider] lazily (via `ref.read` per action)
/// rather than watching it, so the notifier — and the devices/sessions it has
/// already accumulated — survives the device alias changing (e.g. once the
/// signed-in user's profile name finishes loading).
final nearbyDevicesProvider = StateNotifierProvider<NearbyDevicesNotifier, Map<String, LocalDevice>>((ref) {
  return NearbyDevicesNotifier(ref);
});

class NearbyDevicesNotifier extends StateNotifier<Map<String, LocalDevice>> {
  final Ref _ref;
  StreamSubscription<LocalDevice>? _subscription;

  NearbyDevicesNotifier(this._ref) : super({});

  LocalDiscoveryService get _discoveryService => _ref.read(localDiscoveryServiceProvider);
  LocalDevice get _currentDevice => _ref.read(currentLocalDeviceProvider);

  /// Starts listening for UDP Multicast discovery pings and announces presence.
  Future<void> startDiscovery() async {
    await _discoveryService.startMulticastListener(currentDevice: _currentDevice);

    _subscription?.cancel();
    _subscription = _discoveryService.onDeviceDiscovered?.listen((device) {
      addDevice(device);
    });

    // Send initial announcement broadcast
    await _discoveryService.announce(currentDevice: _currentDevice);

    // Run fallback subnet HTTP scan
    unawaited(_discoveryService.scanSubnet(
      currentDevice: _currentDevice,
      onFound: addDevice,
    ));
  }

  void addDevice(LocalDevice device) {
    if (device.fingerprint == _currentDevice.fingerprint) return;
    state = {...state, device.fingerprint: device};
  }

  void clear() {
    state = {};
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Provider for managing active local share transfer sessions.
final localShareSessionsProvider = StateNotifierProvider<LocalShareSessionsNotifier, Map<String, ShareSessionState>>((ref) {
  return LocalShareSessionsNotifier(ref);
});

class LocalShareSessionsNotifier extends StateNotifier<Map<String, ShareSessionState>> {
  final Ref _ref;

  LocalShareSessionsNotifier(this._ref) : super({}) {
    // Listen for incoming server sessions
    _serverService.onSessionUpdated = (session) {
      updateSession(session);
    };
  }

  LocalServerService get _serverService => _ref.read(localServerServiceProvider);
  LocalTransferClientService get _clientService => _ref.read(localTransferClientServiceProvider);
  LocalDevice get _currentDevice => _ref.read(currentLocalDeviceProvider);

  /// Starts local server.
  Future<int> startServer() async {
    return await _serverService.startServer(currentDevice: _currentDevice);
  }

  /// Sends files to a target peer device.
  Future<ShareSessionState> sendFiles({
    required LocalDevice targetDevice,
    required List<LocalFileDto> files,
  }) async {
    return await _clientService.sendFiles(
      targetDevice: targetDevice,
      currentDevice: _currentDevice,
      files: files,
      onProgress: (sessionState) {
        updateSession(sessionState);
      },
    );
  }

  /// Cancels a session.
  Future<void> cancelSession(String sessionId) async {
    final session = state[sessionId];
    if (session != null && session.isOutgoing) {
      await _clientService.cancelSession(sessionId, session.targetDevice);
    }
  }

  void updateSession(ShareSessionState session) {
    state = {...state, session.sessionId: session};
  }
}
