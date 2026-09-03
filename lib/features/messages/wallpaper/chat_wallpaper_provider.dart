import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_wallpaper.dart';
import 'chat_wallpaper_store.dart';

/// Every wallpaper the app currently knows about: the global default plus any
/// per-chat overrides that have been read or written this session.
class ChatWallpaperState {
  const ChatWallpaperState({
    this.global = ChatWallpaper.none,
    this.overrides = const {},
    this.loaded = false,
  });

  final ChatWallpaper global;
  final Map<String, ChatWallpaper> overrides;
  final bool loaded;

  /// What a given chat should paint. An override wins; otherwise the default.
  ChatWallpaper forChat(String conversationId) =>
      overrides[conversationId] ?? global;

  bool hasOverride(String conversationId) =>
      overrides.containsKey(conversationId);

  ChatWallpaperState copyWith({
    ChatWallpaper? global,
    Map<String, ChatWallpaper>? overrides,
    bool? loaded,
  }) => ChatWallpaperState(
    global: global ?? this.global,
    overrides: overrides ?? this.overrides,
    loaded: loaded ?? this.loaded,
  );
}

class ChatWallpaperNotifier extends Notifier<ChatWallpaperState> {
  @override
  ChatWallpaperState build() {
    _load();
    return const ChatWallpaperState();
  }

  ChatWallpaperStore get _store => ref.read(chatWallpaperStoreProvider);

  Future<void> _load() async {
    final global = await _store.readGlobal();
    state = state.copyWith(global: global, loaded: true);
  }

  /// Pulls one chat's override into state. Cheap and idempotent; the chat
  /// screen calls it on open so the first paint is the right background.
  Future<void> ensureLoaded(String conversationId) async {
    if (state.hasOverride(conversationId)) return;
    final stored = await _store.readForChat(conversationId);
    if (stored == null) return;
    state = state.copyWith(
      overrides: {...state.overrides, conversationId: stored},
    );
  }

  Future<void> setGlobal(ChatWallpaper wallpaper) async {
    state = state.copyWith(global: wallpaper);
    await _store.writeGlobal(wallpaper);
  }

  Future<void> setForChat(
    String conversationId,
    ChatWallpaper wallpaper,
  ) async {
    state = state.copyWith(
      overrides: {...state.overrides, conversationId: wallpaper},
    );
    await _store.writeForChat(conversationId, wallpaper);
  }

  /// Removes this chat's override so it follows the global default again.
  Future<void> clearForChat(String conversationId) async {
    final next = Map<String, ChatWallpaper>.of(state.overrides)
      ..remove(conversationId);
    state = state.copyWith(overrides: next);
    await _store.writeForChat(conversationId, null);
  }

  Future<void> clearAllOverrides() async {
    state = state.copyWith(overrides: const {});
    await _store.clearAllOverrides();
  }
}

final chatWallpaperProvider =
    NotifierProvider<ChatWallpaperNotifier, ChatWallpaperState>(
      ChatWallpaperNotifier.new,
    );
