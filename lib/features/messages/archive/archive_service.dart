import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../data/local/chat_message_store.dart';
import '../data/local/chat_sidebar_cache.dart';
import '../data/models/chat_models.dart';
import '../message_e2ee/message_vault.dart';
import '../providers/chat_provider.dart';
import 'archive_api.dart';
import '../data/local/chat_deletion_sync.dart';
import 'archive_exporter.dart';
import 'archive_importer.dart';

/// Raised when a backup or restore is asked for while the message vault is
/// locked. Recoverable, and the message says how: unlock messages first.
class ArchiveLockedError implements Exception {
  const ArchiveLockedError();

  @override
  String toString() =>
      'ArchiveLockedError: unlock secure messages before backing up';
}

/// Drives export and restore, and remembers when the last one succeeded.
///
/// The timestamp is device-local (SharedPreferences), like the wallpaper and
/// the auto-download matrix: it describes what THIS phone has done, and
/// syncing it would make one device's backup look like another's.
class ArchiveService {
  ArchiveService(this._ref);

  final Ref _ref;

  static const _lastBackupKey = 'chat_archive_last_backup_ms';
  static const _lastGenerationKey = 'chat_archive_last_generation';

  ArchiveApi get _api => ArchiveApi(_ref.read(apiClientProvider));

  List<int> _identity() {
    final scalar = _ref.read(messageVaultProvider).archiveRootSecret;
    if (scalar == null || scalar.length != 32) throw const ArchiveLockedError();
    return scalar;
  }

  Future<ArchiveManifest?> manifest() => _api.fetchManifest();

  Future<ArchiveExportResult> backUp({
    required String deviceId,
    required int nowMs,
    void Function(int frames)? onProgress,
  }) async {
    await syncChatDeletions(
      _ref,
      await _ref.read(chatProvider.notifier).ensureCurrentUserId(),
    );
    final store = _ref.read(chatMessageStoreProvider);
    final result =
        await ArchiveExporter(
          store: store,
          api: _api,
          identityScalar: _identity(),
          onProgress: onProgress,
        ).run(
          deviceId: deviceId,
          createdAtMs: nowMs,
          conversations: await _conversations(),
        );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastBackupKey, nowMs);
    await prefs.setInt(_lastGenerationKey, result.generation);
    return result;
  }

  Future<ArchiveImportResult> restore({
    void Function(int restored)? onProgress,
    bool Function()? shouldContinue,
  }) async {
    await syncChatDeletions(
      _ref,
      await _ref.read(chatProvider.notifier).ensureCurrentUserId(),
    );
    if (shouldContinue?.call() == false) throw StateError('Restore cancelled');
    final manifest = await _api.fetchManifest();
    if (manifest == null) {
      throw StateError('there is no archive to restore');
    }
    return ArchiveImporter(
      store: _ref.read(chatMessageStoreProvider),
      api: _api,
      identityScalar: _identity(),
      onProgress: onProgress,
      shouldContinue: shouldContinue,
    ).run(manifest);
  }

  Future<DateTime?> lastBackupAt() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_lastBackupKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Conversation frames come from the sidebar cache, which is the only local
  /// enumeration of conversations there is. Best effort: a restore without
  /// them still gets every message, it just has nothing to name the threads
  /// until the next sidebar fetch.
  Future<List<ChatConversation>> _conversations() async {
    try {
      final userId = _ref.read(chatProvider).currentUserId;
      if (userId.isEmpty) return const [];
      final sidebar = await ChatSidebarCache(
        _ref.read(chatLocalDbProvider),
      ).read(userId);
      if (sidebar == null) return const [];
      return [...sidebar.channels, ...sidebar.dms];
    } catch (_) {
      return const [];
    }
  }
}

final archiveServiceProvider = Provider<ArchiveService>(ArchiveService.new);
