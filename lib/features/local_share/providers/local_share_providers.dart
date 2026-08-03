import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/providers/profile_provider.dart';
import '../models/device_model.dart';
import '../services/discovery_service.dart';
import '../services/local_ip_service.dart';
import '../services/local_server_service.dart';
import '../services/transfer_client_service.dart';

export 'local_share_sessions_provider.dart';
export 'nearby_devices_provider.dart';

/// Persisted per-device identifier — loaded once at bootstrap (see
/// [LocalShareSync]) and stable across app restarts, so a relaunched peer
/// isn't rediscovered as a brand-new device. Seeded with a throwaway value
/// until the real one loads.
final deviceFingerprintProvider = StateProvider<String>((ref) {
  return 'ababilx_pending';
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
    fingerprint: ref.watch(deviceFingerprintProvider),
    ip: '127.0.0.1',
    port: ref.watch(serverPortProvider),
    protocol: 'http',
    download: true,
  );
});

/// The port the receive server actually bound to — may differ from the
/// default 12045 if that port was already taken. Discovery must advertise
/// this, not the default, or peers dial a dead port.
final serverPortProvider = StateProvider<int>((ref) => 12045);

/// Service providers
final localIpServiceProvider = Provider((ref) => LocalIpService());
final localDiscoveryServiceProvider = Provider(
  (ref) => LocalDiscoveryService(),
);
final localServerServiceProvider = Provider((ref) => LocalServerService());
final localTransferClientServiceProvider = Provider(
  (ref) => LocalTransferClientService(),
);
