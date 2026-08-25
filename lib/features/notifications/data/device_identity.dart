import 'dart:math';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fcm_log.dart';

/// Stable identity of this handset, registered alongside the FCM token.
///
/// A token is not a device: a reinstall or an FCM rotation mints a new one and
/// leaves the previous `device_tokens` row behind, still delivering. The server
/// then pushed the same message to one phone twice — visible as duplicate
/// notifications. Registering an identity lets it drop the rows this device
/// left behind under older tokens.
///
/// `Settings.Secure.ANDROID_ID` is the primary source because it survives a
/// reinstall for the same signing key. When it is unavailable (or on iOS) a
/// random id is generated once and kept in shared preferences, which at least
/// collapses token rotations within one install.
class DeviceIdentity {
  DeviceIdentity._();

  static const _channel = MethodChannel('com.ababilx.app/device');
  static const _prefsKey = 'device_identity_v1';

  static String? _cached;

  static Future<String> get() async {
    final cached = _cached;
    if (cached != null && cached.isNotEmpty) return cached;

    final native = await _nativeId();
    if (native.isNotEmpty) {
      _cached = native;
      return native;
    }
    final stored = await _storedId();
    _cached = stored;
    return stored;
  }

  static Future<String> _nativeId() async {
    try {
      final id = await _channel.invokeMethod<String>('deviceId');
      return id?.trim() ?? '';
    } on MissingPluginException {
      // No Activity behind the channel — a background isolate registering a
      // refreshed token falls back to the stored id, which it shares.
      return '';
    } catch (e) {
      fcmLog('device.identity.native.fail', e);
      return '';
    }
  }

  static Future<String> _storedId() async {
    final prefs = SharedPreferencesAsync();
    final existing = await prefs.getString(_prefsKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = _randomId();
    await prefs.setString(_prefsKey, generated);
    return generated;
  }

  static String _randomId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
