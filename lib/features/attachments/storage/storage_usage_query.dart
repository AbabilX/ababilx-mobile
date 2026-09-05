import '../../messages/data/local/chat_local_db.dart';
import '../data/models/attachment_handle.dart';
import 'storage_usage.dart';

/// Reads of the local attachment store, for Manage storage.
///
/// Only `ready` rows are counted: an absent or failed row occupies no disk,
/// and a half-transferred `.part` is swept on its own schedule. Counting them
/// would show a number the user cannot free.
///
/// Every method swallows its errors and returns an empty result — the same
/// rule the rest of the local layer follows.
class StorageUsageQuery {
  StorageUsageQuery(this._db);

  final ChatLocalDb _db;

  static final _ready = AttachmentTransferState.ready.index;

  Future<StorageUsage> total() async {
    final bytes = <StorageBucket, int>{};
    final counts = <StorageBucket, int>{};
    for (final row in await _readyRows()) {
      final bucket = storageBucketOf(
        fileName: row.fileName,
        contentType: row.contentType,
      );
      bytes[bucket] = (bytes[bucket] ?? 0) + row.receivedBytes;
      counts[bucket] = (counts[bucket] ?? 0) + 1;
    }
    return StorageUsage(bytes: bytes, counts: counts);
  }

  /// Biggest first — the only order Review storage is useful in.
  ///
  /// [conversationId] filters to one chat; the conversation carried back on
  /// each item is *a* chat the file appears in, since one blob can be
  /// referenced from several.
  Future<List<StorageItem>> items({
    int limit = 300,
    String conversationId = '',
    StorageBucket? bucket,
  }) async {
    try {
      final refs = await _conversationByUrlKey();
      final keys = conversationId.isEmpty
          ? null
          : refs.entries
                .where((e) => e.value.contains(conversationId))
                .map((e) => e.key)
                .toSet();
      final rows = await _readyRows();
      final items = <StorageItem>[];
      for (final row in rows) {
        if (keys != null && !keys.contains(row.urlKey)) continue;
        final item = StorageItem(
          urlKey: row.urlKey,
          fileName: row.fileName,
          contentType: row.contentType,
          bytes: row.receivedBytes,
          localPath: row.localPath ?? '',
          downloadedAtMs: row.downloadedAtMs ?? 0,
          conversationId: conversationId.isNotEmpty
              ? conversationId
              : (refs[row.urlKey]?.first ?? ''),
        );
        if (bucket != null && item.bucket != bucket) continue;
        items.add(item);
      }
      items.sort((a, b) => b.bytes.compareTo(a.bytes));
      return items.length > limit ? items.sublist(0, limit) : items;
    } catch (_) {
      return const [];
    }
  }

  /// Per-chat totals, biggest first.
  Future<List<ConversationStorage>> byConversation() async {
    try {
      final refs = await _conversationByUrlKey();
      final rows = await _readyRows();
      final bytes = <String, int>{};
      final counts = <String, int>{};
      for (final row in rows) {
        for (final conversationId in refs[row.urlKey] ?? const <String>{}) {
          if (conversationId.isEmpty) continue;
          bytes[conversationId] =
              (bytes[conversationId] ?? 0) + row.receivedBytes;
          counts[conversationId] = (counts[conversationId] ?? 0) + 1;
        }
      }
      final out = [
        for (final entry in bytes.entries)
          ConversationStorage(
            conversationId: entry.key,
            bytes: entry.value,
            count: counts[entry.key] ?? 0,
          ),
      ]..sort((a, b) => b.bytes.compareTo(a.bytes));
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// Which chats each blob is referenced from. One query rather than one per
  /// row: a store with a few thousand files would otherwise make Manage
  /// storage take seconds to open.
  Future<Map<String, Set<String>>> _conversationByUrlKey() async {
    final out = <String, Set<String>>{};
    try {
      final rows = await _db
          .customSelect(
            'SELECT DISTINCT url_key, conversation_id FROM attachment_refs',
          )
          .get();
      for (final row in rows) {
        out
            .putIfAbsent(row.read<String>('url_key'), () => <String>{})
            .add(row.read<String>('conversation_id'));
      }
    } catch (_) {}
    return out;
  }

  Future<List<AttachmentBlob>> _readyRows() async {
    try {
      return await (_db.select(
        _db.attachmentBlobs,
      )..where((t) => t.transferState.equals(_ready))).get();
    } catch (_) {
      return const [];
    }
  }
}
