part of 'chat_provider.dart';

/// Cache hydrate / persist for sidebar (WhatsApp-style instant list).
mixin _ChatCacheMixin on Notifier<ChatState> {
  ChatSidebarCache get sidebarCache;

  Future<bool> hydrateSidebarFromCache() async {
    final userId = state.currentUserId;
    if (userId.isEmpty) return false;
    try {
      final cached = await sidebarCache.read(userId);
      if (cached == null) return false;
      if (cached.dms.isEmpty && cached.channels.isEmpty) return false;
      state = state.copyWith(
        dms: sortDms(cached.dms),
        channels: sortChannels(cached.channels),
        sidebarLoading: false,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> persistSidebar(ChatSidebar sidebar) async {
    final userId = state.currentUserId;
    if (userId.isEmpty) return;
    try {
      await sidebarCache.write(userId, sidebar);
    } catch (_) {}
  }

  Future<void> clearSidebarCache() async {
    try {
      await sidebarCache.clearAll();
    } catch (_) {}
  }
}
