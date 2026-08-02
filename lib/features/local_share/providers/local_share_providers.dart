import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device_model.dart';
import '../models/file_dto.dart';
import '../models/session_state.dart';
import '../services/discovery_service.dart';
import '../services/local_ip_service.dart';
import '../services/local_server_service.dart';
import '../services/transfer_client_service.dart';

/// Provider for current device identity information (Mobile).
final currentLocalDeviceProvider = Provider<LocalDevice>((ref) {
  final platformName = Platform.isAndroid ? 'Android' : 'iOS';
  final fingerprint = 'ababilx_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';

  return LocalDevice(
    alias: 'AbabilX ($platformName)',
    version: '2.1',
    deviceModel: platformName,
    deviceType: 'mobile',
    fingerprint: fingerprint,
    ip: '127.0.0.1',
    port: 53317,
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
final nearbyDevicesProvider = StateNotifierProvider<NearbyDevicesNotifier, Map<String, LocalDevice>>((ref) {
  return NearbyDevicesNotifier(
    ref.watch(localDiscoveryServiceProvider),
    ref.watch(currentLocalDeviceProvider),
  );
});

class NearbyDevicesNotifier extends StateNotifier<Map<String, LocalDevice>> {
  final LocalDiscoveryService _discoveryService;
  final LocalDevice _currentDevice;
  StreamSubscription<LocalDevice>? _subscription;

  NearbyDevicesNotifier(this._discoveryService, this._currentDevice) : super({});

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
  return LocalShareSessionsNotifier(
    ref.watch(localServerServiceProvider),
    ref.watch(localTransferClientServiceProvider),
    ref.watch(currentLocalDeviceProvider),
  );
});

class LocalShareSessionsNotifier extends StateNotifier<Map<String, ShareSessionState>> {
  final LocalServerService _serverService;
  final LocalTransferClientService _clientService;
  final LocalDevice _currentDevice;

  LocalShareSessionsNotifier(
    this._serverService,
    this._clientService,
    this._currentDevice,
  ) : super({}) {
    // Listen for incoming server sessions
    _serverService.onSessionUpdated = (session) {
      updateSession(session);
    };
  }

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
