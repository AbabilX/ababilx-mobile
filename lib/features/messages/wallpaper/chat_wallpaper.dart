import 'dart:convert';

import 'package:flutter/material.dart';

/// Where a chat background comes from.
enum ChatWallpaperKind { none, preset, photo }

/// A chat background.
///
/// Signal models this as a per-chat value that falls back to a global default,
/// plus a "dim in dark theme" flag — a photo bright enough to read against in
/// daylight is glaring at night, and dimming it is cheaper than asking for two
/// pictures. Same three fields here.
@immutable
class ChatWallpaper {
  const ChatWallpaper({
    this.kind = ChatWallpaperKind.none,
    this.presetId = '',
    this.photoPath = '',
    this.dimInDark = true,
  });

  factory ChatWallpaper.preset(String id) =>
      ChatWallpaper(kind: ChatWallpaperKind.preset, presetId: id);

  factory ChatWallpaper.photo(String path) =>
      ChatWallpaper(kind: ChatWallpaperKind.photo, photoPath: path);

  static const ChatWallpaper none = ChatWallpaper();

  final ChatWallpaperKind kind;
  final String presetId;
  final String photoPath;
  final bool dimInDark;

  bool get isSet => kind != ChatWallpaperKind.none;

  ChatWallpaper copyWith({bool? dimInDark}) => ChatWallpaper(
    kind: kind,
    presetId: presetId,
    photoPath: photoPath,
    dimInDark: dimInDark ?? this.dimInDark,
  );

  String encode() => jsonEncode({
    'kind': kind.name,
    'preset': presetId,
    'photo': photoPath,
    'dim': dimInDark,
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
      other.dimInDark == dimInDark;

  @override
  int get hashCode => Object.hash(kind, presetId, photoPath, dimInDark);
}

/// One of the built-in backgrounds.
@immutable
class ChatWallpaperPreset {
  const ChatWallpaperPreset(this.id, this.colors);

  final String id;

  /// One colour paints flat; two or more paint as a diagonal gradient, which
  /// is how Signal's preset set is built.
  final List<Color> colors;

  Gradient? get gradient => colors.length < 2
      ? null
      : LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        );

  Color get solid => colors.first;
}

/// The built-in set. Solids first, then gradients, same shape as Signal's
/// picker so the grid reads left-to-right from calm to loud.
const List<ChatWallpaperPreset> chatWallpaperPresets = [
  ChatWallpaperPreset('slate', [Color(0xFF1F2430)]),
  ChatWallpaperPreset('ink', [Color(0xFF0F172A)]),
  ChatWallpaperPreset('sand', [Color(0xFFEFE7DA)]),
  ChatWallpaperPreset('mist', [Color(0xFFE6ECF5)]),
  ChatWallpaperPreset('sage', [Color(0xFFDDE9DF)]),
  ChatWallpaperPreset('rose', [Color(0xFFF6E2E6)]),
  ChatWallpaperPreset('indigo', [Color(0xFF6366F1), Color(0xFF312E81)]),
  ChatWallpaperPreset('dusk', [Color(0xFF7C3AED), Color(0xFFDB2777)]),
  ChatWallpaperPreset('ocean', [Color(0xFF0EA5E9), Color(0xFF1E3A8A)]),
  ChatWallpaperPreset('forest', [Color(0xFF34D399), Color(0xFF065F46)]),
  ChatWallpaperPreset('ember', [Color(0xFFF97316), Color(0xFF9A3412)]),
  ChatWallpaperPreset('graphite', [Color(0xFF334155), Color(0xFF0B1120)]),
];

ChatWallpaperPreset? chatWallpaperPresetById(String id) {
  for (final preset in chatWallpaperPresets) {
    if (preset.id == id) return preset;
  }
  return null;
}
