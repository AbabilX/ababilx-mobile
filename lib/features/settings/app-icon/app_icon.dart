import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One selectable launcher icon.
@immutable
class AppIconOption {
  const AppIconOption({
    required this.id,
    required this.label,
    required this.background,
  });

  final String id;
  final String label;

  /// The plate behind the mark, mirrored from the alias's adaptive icon so the
  /// picker shows what the launcher will show.
  final Color background;
}

/// Must stay in step with `AppIconChannel.ALIASES` on the Android side.
const List<AppIconOption> appIconOptions = [
  AppIconOption(id: 'default', label: 'Default', background: Color(0xFF12121A)),
  AppIconOption(id: 'ink', label: 'Ink', background: Color(0xFF0F172A)),
  AppIconOption(id: 'indigo', label: 'Indigo', background: Color(0xFF6366F1)),
  AppIconOption(id: 'forest', label: 'Forest', background: Color(0xFF065F46)),
];

/// Switches the launcher icon by enabling one `activity-alias` and disabling
/// the others. Android only; every method answers harmlessly elsewhere.
class AppIcon {
  const AppIcon._();

  static const MethodChannel _channel = MethodChannel(
    'com.ababilx.app/app_icon',
  );

  static bool get supported => !kIsWeb && Platform.isAndroid;

  static Future<String> current() async {
    if (!supported) return 'default';
    try {
      return await _channel.invokeMethod<String>('current') ?? 'default';
    } on PlatformException {
      return 'default';
    } on MissingPluginException {
      return 'default';
    }
  }

  static Future<bool> select(String id) async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('set', {'id': id}) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
