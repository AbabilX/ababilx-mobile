import 'dart:io' show Platform;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'network_class.dart';

/// The current [NetworkClass], answered on demand rather than watched.
///
/// A stream provider would have to stay listened-to for its value to be
/// readable, and the one caller that matters — the auto-download gate — is a
/// background service with no widget behind it. Asking at decision time, with
/// a short cache so a burst of arriving messages costs one probe, avoids that
/// whole lifecycle problem.
class NetworkProbe {
  NetworkProbe({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// Long enough that a screenful of new messages shares one answer, short
  /// enough that walking out of Wi-Fi is noticed before the next batch.
  static const cacheFor = Duration(seconds: 10);

  static const _channel = MethodChannel('com.ababilx.app/network');

  NetworkClass? _cached;
  DateTime? _cachedAt;

  Future<NetworkClass> current() async {
    final at = _cachedAt;
    final cached = _cached;
    if (cached != null &&
        at != null &&
        DateTime.now().difference(at) < cacheFor) {
      return cached;
    }
    final network = await _read();
    _cached = network;
    _cachedAt = DateTime.now();
    return network;
  }

  /// Drops the cache. Called when the user changes a setting, so the next
  /// decision is made against a fresh reading rather than a stale one.
  void invalidate() {
    _cached = null;
    _cachedAt = null;
  }

  Future<NetworkClass> _read() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return resolveNetworkClass(results, roaming: await isRoaming());
    } catch (_) {
      // A probe that cannot read must not block media. Cellular is the
      // middle answer: stricter than Wi-Fi, never mistaken for roaming.
      return NetworkClass.cellular;
    }
  }

  /// Android only. Every other platform reports false — an unanswerable
  /// question must not silently disable the user's Cellular choice.
  static Future<bool> isRoaming() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isRoaming') ?? false;
    } catch (_) {
      return false;
    }
  }
}

final networkProbeProvider = Provider<NetworkProbe>((ref) => NetworkProbe());

/// Live class for the UI — this one *is* watched, so a stream is right here.
final networkClassProvider = StreamProvider<NetworkClass>((ref) async* {
  final probe = ref.watch(networkProbeProvider);
  yield await probe.current();
  await for (final _ in Connectivity().onConnectivityChanged) {
    probe.invalidate();
    yield await probe.current();
  }
});
