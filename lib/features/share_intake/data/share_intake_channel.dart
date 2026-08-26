import 'dart:io';

import 'package:flutter/services.dart';

/// Dart end of `ShareIntakeChannel.kt`.
///
/// Android only. iOS has no share extension yet, so every call here is a
/// no-op there rather than a MissingPluginException — and the same guard keeps
/// widget tests, which have no platform channels, from throwing.
class ShareIntakeChannel {
  const ShareIntakeChannel();

  static const _method = MethodChannel('com.ababilx.app/share_intake');
  static const _events = EventChannel('com.ababilx.app/share_intake/events');

  bool get _supported => !kIsAndroidUnsupported;

  /// The share that cold-started the app, as raw JSON. Native hands it over
  /// exactly once.
  Future<String?> initialShare() async {
    if (!_supported) return null;
    return _method.invokeMethod<String>('getInitialShare');
  }

  /// Shares that arrive while the app is already running.
  Stream<String> shares() {
    if (!_supported) return const Stream<String>.empty();
    return _events.receiveBroadcastStream().map((e) => e as String);
  }

  /// Forgets any share native is still holding, so a hot restart does not
  /// replay one the user already dealt with.
  Future<void> clear() async {
    if (!_supported) return;
    await _method.invokeMethod<void>('clear');
  }

  /// Copies one shared item out of its content provider and into our cache,
  /// returning the path. Deliberately on-demand: this is the only point where
  /// a shared file's bytes are duplicated, and it happens after the user has
  /// picked a recipient.
  Future<String?> materialize(String uri, String fileName) async {
    if (!_supported) return null;
    return _method.invokeMethod<String>('materialize', {
      'uri': uri,
      'name': fileName,
    });
  }

  /// A small JPEG preview decoded from the original, for images and videos.
  /// Null for anything else, or when the provider will not give one up.
  Future<Uint8List?> thumbnail(String uri, {int maxPx = 256}) async {
    if (!_supported) return null;
    try {
      return await _method.invokeMethod<Uint8List>('thumbnail', {
        'uri': uri,
        'maxPx': maxPx,
      });
    } on PlatformException {
      // A preview is decoration; never let one failing image break the screen.
      return null;
    }
  }
}

/// True on every platform whose share sheet we do not implement.
final bool kIsAndroidUnsupported = !Platform.isAndroid;
