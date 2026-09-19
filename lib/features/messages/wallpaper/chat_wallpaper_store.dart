import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_wallpaper.dart';

/// Wallpapers live on the device.
///
/// Deliberately not synced: a wallpaper is a property of *this* phone's chat
/// window, and syncing one would mean a migration, endpoints and a web picker
/// for something nobody expects to follow them between devices. Signal keeps
/// its own per-chat wallpapers local for the same reason.
class ChatWallpaperStore {
  const ChatWallpaperStore();

  static const String _globalKey = 'ababilx_chat_wallpaper_global';
  static const String _perChatPrefix = 'ababilx_chat_wallpaper_';

  /// Set once at process start. Prevents re-applying the bundled default after
  /// an upgrade user (or someone who chose "No wallpaper") clears the key.
  static const String _shippedDefaultKey =
      'ababilx_chat_wallpaper_shipped_default_v1';

  /// Same string as `OnboardingGate.preferenceKey`. Inlined so this store does
  /// not import the auth widget tree. A returning install has seen onboarding;
  /// at `main()` a fresh one has not written it yet.
  static const String _onboardingSeenKey = 'messaging_onboarding_v1_seen';

  /// Writes the theme-aware mobile pair as the global wallpaper on a brand-new
  /// install only. Upgrades keep plain (or whatever they already chose).
  ///
  /// Call once from `main()` before other features write prefs that would make
  /// a fresh install look like a returning one. Safe to call repeatedly.
  Future<void> shipDefaultIfFreshInstall() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_shippedDefaultKey)) return;

    final keys = prefs.getKeys();
    final returning =
        keys.contains(_onboardingSeenKey) ||
        keys.any((k) => k.startsWith('ababilx_'));

    if (!returning) {
      // dimInDark off: the pair already has a dark painting.
      await prefs.setString(
        _globalKey,
        ChatWallpaper.preset(
          chatWallpaperMobileId,
          dimInDark: false,
        ).encode(),
      );
    }
    await prefs.setBool(_shippedDefaultKey, true);
  }

  /// Absence means no wallpaper, which is also what an unset one decodes to —
  /// so the write below can drop the key rather than store a blank.
  Future<ChatWallpaper> readGlobal() async {
    final prefs = await SharedPreferences.getInstance();
    return ChatWallpaper.decode(prefs.getString(_globalKey));
  }

  Future<void> writeGlobal(ChatWallpaper wallpaper) async {
    final prefs = await SharedPreferences.getInstance();
    if (!wallpaper.isSet) {
      await prefs.remove(_globalKey);
      return;
    }
    await prefs.setString(_globalKey, wallpaper.encode());
  }

  /// Null means "no override" — the chat follows the global default. That is
  /// different from a stored [ChatWallpaper.none], which means the user chose
  /// a plain background for this one chat.
  Future<ChatWallpaper?> readForChat(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_perChatPrefix$conversationId');
    if (raw == null) return null;
    return ChatWallpaper.decode(raw);
  }

  Future<void> writeForChat(
    String conversationId,
    ChatWallpaper? wallpaper,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_perChatPrefix$conversationId';
    if (wallpaper == null) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, wallpaper.encode());
  }

  /// Drops every per-chat override, leaving only the global default.
  Future<void> clearAllOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_perChatPrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}

final chatWallpaperStoreProvider = Provider<ChatWallpaperStore>(
  (ref) => const ChatWallpaperStore(),
);
