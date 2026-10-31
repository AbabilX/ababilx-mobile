import 'dart:convert';

import 'package:flutter/material.dart';

import 'chat_wallpaper_presets.dart';

// The preset catalogue is a separate file but the same concept: everything
// that imports a wallpaper wants the presets too, so it is re-exported rather
// than made a second import at 20 call sites.
export 'chat_wallpaper_presets.dart';

/// Where a chat background comes from.
enum ChatWallpaperKind { none, preset, photo }

/// The faintest a wallpaper may be drawn.
///
/// Not zero: a fully transparent wallpaper is indistinguishable from having
/// none, so the slider's floor would look like a bug rather than a setting.
const double chatWallpaperMinOpacity = 0.05;

/// How strongly the built-in doodle pattern draws until somebody moves the
/// slider. It is a busy, high-contrast line drawing, so full strength fights
/// the bubbles; at the floor it reads as texture behind the chat.
const double chatWallpaperDefaultOpacity = 0.2;

/// What the default draws as for a theme-pair pattern in light theme.
///
/// Dark lines on a pale ground read much louder than pale lines on a dark
/// one, so the same 20% that sits quietly at night is busy by day. Below the
/// default light draws at half; above it the range stretches back to 100%.
const double chatWallpaperLightPatternFloor = 0.05;

/// A chat background.
///
/// The reference app models this as a per-chat value that falls back to a
/// global default, plus a "dim in dark theme" flag — a photo bright enough to
/// read against in daylight is glaring at night, and dimming it is cheaper than
/// asking for two pictures.
///
/// [opacity] is ours, and is a different question from [dimInDark]: dimming is
/// conditional on the theme and paints black OVER the wallpaper, while opacity
/// is unconditional and fades the wallpaper INTO the chat surface. Someone who
/// wants a picture they can barely notice at noon needs the second one.
@immutable
class ChatWallpaper {
  const ChatWallpaper({
    this.kind = ChatWallpaperKind.none,
    this.presetId = '',
    this.photoPath = '',
    this.dimInDark = true,
    this.opacity = 1,
  });

  factory ChatWallpaper.preset(
    String id, {
    bool dimInDark = true,
    double opacity = 1,
  }) => ChatWallpaper(
    kind: ChatWallpaperKind.preset,
    presetId: id,
    dimInDark: dimInDark,
    opacity: opacity,
  );

  factory ChatWallpaper.photo(
    String path, {
    bool dimInDark = true,
    double opacity = 1,
  }) => ChatWallpaper(
    kind: ChatWallpaperKind.photo,
    photoPath: path,
    dimInDark: dimInDark,
    opacity: opacity,
  );

  static const ChatWallpaper none = ChatWallpaper();

  /// Built-in theme pair used whenever nothing (or an explicit "none") is stored.
  /// Chats always have a wallpaper; there is no plain opt-out.
  static ChatWallpaper get builtInDefault => ChatWallpaper.preset(
    chatWallpaperMobileId,
    dimInDark: false,
    opacity: chatWallpaperDefaultOpacity,
  );

  final ChatWallpaperKind kind;
  final String presetId;
  final String photoPath;
  final bool dimInDark;

  /// 0..1. Always read through [drawOpacity], never raw — a value decoded from
  /// storage written by an older or newer build has no guarantee behind it.
  final double opacity;

  bool get isSet => kind != ChatWallpaperKind.none;

  /// What painters / bubble contrast use: unset falls back to [builtInDefault].
  ChatWallpaper get effective => isSet ? this : builtInDefault;

  /// What the painters actually use.
  double get drawOpacity => opacity.clamp(chatWallpaperMinOpacity, 1.0);

  /// [drawOpacity] as painted in [brightness]. A theme-pair pattern in light
  /// theme draws the default at [chatWallpaperLightPatternFloor], anything
  /// fainter at the same ratio, and stretches the rest back up to 1.
  double paintOpacity(Brightness brightness) {
    final value = drawOpacity;
    final pattern =
        kind == ChatWallpaperKind.preset &&
        (chatWallpaperPresetById(presetId)?.isThemePair ?? false);
    if (!pattern || brightness != Brightness.light) return value;
    const floor = chatWallpaperLightPatternFloor;
    const base = chatWallpaperDefaultOpacity;
    if (value <= base) return value * floor / base;
    return floor + (value - base) * (1 - floor) / (1 - base);
  }

  ChatWallpaper copyWith({bool? dimInDark, double? opacity}) => ChatWallpaper(
    kind: kind,
    presetId: presetId,
    photoPath: photoPath,
    dimInDark: dimInDark ?? this.dimInDark,
    opacity: opacity ?? this.opacity,
  );

  String encode() => jsonEncode({
    'kind': kind.name,
    'preset': presetId,
    'photo': photoPath,
    'dim': dimInDark,
    'opacity': opacity,
  });

  static ChatWallpaper decode(String? raw) {
    if (raw == null || raw.isEmpty) return none;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return ChatWallpaper(
        kind: ChatWallpaperKind.values.firstWhere(
          (value) => value.name == json['kind'],
          orElse: () => ChatWallpaperKind.none,
        ),
        presetId: json['preset'] as String? ?? '',
        photoPath: json['photo'] as String? ?? '',
        dimInDark: json['dim'] as bool? ?? true,
        // Absent means a value written before opacity existed, which was
        // always fully opaque.
        opacity: (json['opacity'] as num?)?.toDouble() ?? 1,
      );
    } catch (_) {
      return none;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ChatWallpaper &&
      other.kind == kind &&
      other.presetId == presetId &&
      other.photoPath == photoPath &&
      other.dimInDark == dimInDark &&
      other.opacity == opacity;

  @override
  int get hashCode =>
      Object.hash(kind, presetId, photoPath, dimInDark, opacity);
}
