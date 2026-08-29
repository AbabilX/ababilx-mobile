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
    this.previewAsset,
    this.previewIcon,
  });

  final String id;
  final String label;

  /// The plate behind the mark, mirrored from the alias's adaptive icon so the
  /// picker shows what the launcher will show.
  final Color background;

  /// Project asset for an original launcher mark, when one is available.
  final String? previewAsset;

  /// A lightweight Flutter preview of the matching Android adaptive icon.
  final IconData? previewIcon;
}

/// Must stay in step with `AppIconChannel.ALIASES` on the Android side.
const List<AppIconOption> appIconOptions = [
  AppIconOption(id: 'default', label: 'Default', background: Color(0xFF12121A)),
  AppIconOption(
    id: 'calendar',
    label: 'Calendar',
    background: Color(0xFF2563EB),
    previewAsset: 'assets/icon/alternates/calendar.png',
  ),
  AppIconOption(
    id: 'notes',
    label: 'Notes',
    background: Color(0xFF7C3AED),
    previewAsset: 'assets/icon/alternates/notes.png',
  ),
  AppIconOption(
    id: 'weather',
    label: 'Weather',
    background: Color(0xFF0284C7),
    previewAsset: 'assets/icon/alternates/weather.png',
  ),
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
