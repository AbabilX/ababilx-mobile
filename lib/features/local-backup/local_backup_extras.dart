import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/theme/theme_mode_provider.dart';
import '../../shared/avatar-store/avatar_store.dart';
import '../../shared/media/media_quality.dart';
import '../attachments/auto_download/auto_download_store.dart';
import '../calls/data/call_log_cache.dart';
import '../calls/data/call_log_repository.dart';
import '../calls/data/models/call_log_entry.dart';
import '../calls/data/restored_call_log.dart';
import '../calls/favorites/call_favorites_provider.dart';
import '../calls/providers/call_log_provider.dart';
import '../chat-lock/data/chat_lock_index.dart';
import '../chat-lock/providers/chat_locks_provider.dart';
import '../messages/data/local/chat_sidebar_cache.dart';
import '../messages/data/models/chat_models.dart';
import '../messages/message_e2ee/sidebar_preview.dart';
import '../messages/nickname/contact_nickname_provider.dart';
import '../messages/providers/chat_provider.dart';
import '../messages/wallpaper/chat_wallpaper_photos.dart';
import '../messages/wallpaper/chat_wallpaper_provider.dart';
import 'extras/backup_extras_export.dart';
import 'extras/backup_extras_restore.dart';
import 'extras/backup_prefs.dart';
import 'format/backup_file_writer.dart';

/// The parts of a backup beyond messages, wired to this app's stores.
class LocalBackupExtras {
  LocalBackupExtras(this._ref);

  final Ref _ref;

  /// Server pages read for the call log at backup time. The phone keeps only
  /// the first page and whatever an earlier restore brought.
  static const _maxCallPages = 50;

  static Future<Directory> _wallpaperDir() async => Directory(
    '${(await getApplicationSupportDirectory()).path}/chat_wallpapers',
  );

  /// [calls] is [allCalls], when the caller started it earlier.
  Future<BackupExtrasStats> write(
    BackupFileWriter writer, {
    List<CallLogEntry>? calls,
  }) async {
    await AvatarStore.instance.init();
    return writeBackupExtras(
      writer,
      calls: calls ?? await allCalls(),
      wallpaperDir: await _wallpaperDir(),
      avatarDir: AvatarStore.instance.directory,
      avatars: AvatarStore.instance.entries,
    );
  }

  /// Every call this phone can reach: restored, cached, on screen, then the
  /// server's history page by page while it answers (offline, what is local).
  Future<List<CallLogEntry>> allCalls() async {
    final byId = <String, CallLogEntry>{};
    void add(Iterable<CallLogEntry> calls) {
      for (final c in calls) {
        if (c.id.isNotEmpty) byId[c.id] = c;
      }
    }

    add(await _ref.read(restoredCallLogProvider).read());
    add((await _ref.read(callLogCacheProvider).read())?.calls ?? const []);
    add(_ref.read(callLogProvider).calls);
    try {
      final repo = _ref.read(callLogRepositoryProvider);
      String? before;
      for (var i = 0; i < _maxCallPages; i++) {
        final page = await repo.page(before: before, limit: 100);
        add(page.calls);
        if (page.calls.isEmpty || page.nextCursor.isEmpty) break;
        before = page.nextCursor;
      }
    } catch (error) {
      debugPrint('[LocalBackup] call log from server stopped: $error');
    }
    return byId.values.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  Future<BackupExtrasCollector> collector() async {
    await AvatarStore.instance.init();
    return BackupExtrasCollector(
      wallpaperDir: await _wallpaperDir(),
      avatarDir: AvatarStore.instance.directory,
    );
  }

  /// Applies what [c] gathered. Each part on its own: one that fails leaves
  /// the others restored.
  Future<void> apply(BackupExtrasCollector c, String userId) async {
    await _step('chat list', () => _mergeChatList(c.conversations, userId));
    await _step('calls', () async {
      await _ref.read(restoredCallLogProvider).merge(userId, c.calls);
      await _ref.read(callLogProvider.notifier).reloadRestored();
    });
    await _step('settings', () async {
      final n = await BackupPrefs.restore(c.prefs, rewrite: c.rewritePath);
      await ChatLockIndex.preload();
      debugPrint('[LocalBackup] restore settings=$n');
    });
    await _step('pictures', () async {
      AvatarStore.instance.adoptRestored(c.avatars);
    });
    _ref
      ..invalidate(themeModeProvider)
      ..invalidate(chatLocksProvider)
      ..invalidate(contactNicknamesProvider)
      ..invalidate(callFavoritesProvider)
      ..invalidate(chatWallpaperProvider)
      ..invalidate(chatWallpaperPhotosProvider)
      ..invalidate(autoDownloadSettingsProvider)
      ..invalidate(mediaQualityProvider);
    debugPrint(
      '[LocalBackup] restore extras: chats=${c.conversations.length} '
      'calls=${c.calls.length} prefs=${c.prefs.length} '
      'avatars=${c.avatars.length}',
    );
  }

  /// The backup's chats join the phone's saved list (the phone's own rows
  /// win), so the list draws offline right after a restore — before, or
  /// without, the server answering. The next sidebar fetch replaces it with
  /// the server's list, which decides membership.
  Future<void> _mergeChatList(
    List<ChatConversation> rows,
    String userId,
  ) async {
    if (rows.isEmpty) return;
    final cache = ChatSidebarCache(_ref.read(chatLocalDbProvider));
    final current = await cache.read(userId) ?? const ChatSidebar();
    final known = {
      for (final c in [...current.dms, ...current.channels]) c.id,
    };
    final fresh = [
      for (final c in rows)
        if (!known.contains(c.id)) previewForDisk(c),
    ];
    if (fresh.isEmpty) return;
    await cache.write(
      userId,
      ChatSidebar(
        channels: [...current.channels, ...fresh.where((c) => !c.isDm)],
        dms: [...current.dms, ...fresh.where((c) => c.isDm)],
      ),
    );
    final chat = _ref.read(chatProvider);
    if (chat.dms.isEmpty && chat.channels.isEmpty) {
      await _ref.read(chatProvider.notifier).hydrateSidebarFromCache();
    }
  }

  static Future<void> _step(String name, Future<void> Function() run) async {
    try {
      await run();
    } catch (error) {
      debugPrint('[LocalBackup] restore $name failed: $error');
    }
  }
}
