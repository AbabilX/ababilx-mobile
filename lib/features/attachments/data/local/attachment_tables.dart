import 'package:drift/drift.dart';

/// One row per distinct remote object (V5) — the local mirror of an R2 asset.
///
/// Keyed by [urlKey] (a hash of the normalised remote URL) and **not** by
/// attachment id, because forwarding copies one `file_url` across many
/// `chat_message_attachments` rows. URL-keying makes a forwarded file
/// instantly available with no second download, and makes the same photo
/// pasted into three conversations cost one file on disk.
///
/// [localPath] is the canonical bytes in the app-private sandbox — the source
/// every renderer reads once [transferState] is ready. [exportedPath] is a
/// user-visible *copy* (gallery / Downloads); deleting it never affects
/// playback.
@TableIndex(
  name: 'idx_attachment_blobs_lru',
  columns: {#transferState, #lastAccessMs},
)
@TableIndex(name: 'idx_attachment_blobs_content_hash', columns: {#contentHash})
class AttachmentBlobs extends Table {
  TextColumn get urlKey => text()();
  TextColumn get remoteUrl => text()();

  /// Absolute path of the finished file. Null unless the row is ready.
  TextColumn get localPath => text().nullable()();
  TextColumn get fileName => text().withDefault(const Constant(''))();
  TextColumn get contentType => text().withDefault(const Constant(''))();

  /// Server-verified `size_bytes`. 0 when the message predates verification.
  IntColumn get expectedBytes => integer().withDefault(const Constant(0))();

  /// Length of the sticky `.part` file — what a resumed request ranges from.
  IntColumn get receivedBytes => integer().withDefault(const Constant(0))();

  /// [AttachmentTransferState.index]. Stored as a raw int so adding a state
  /// later is not a migration.
  IntColumn get transferState => integer().withDefault(const Constant(0))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().withDefault(const Constant(''))();

  IntColumn get downloadedAtMs => integer().nullable()();

  /// Drives LRU eviction once the disk budget is exceeded.
  IntColumn get lastAccessMs => integer().withDefault(const Constant(0))();

  /// Legacy, never written any more. A finished download used to be copied
  /// straight into the public gallery and these recorded that copy; nothing
  /// auto-publishes now, so they stay null. Kept only so the stored schema
  /// does not need a migration to lose two unread columns.
  IntColumn get exportedAtMs => integer().nullable()();
  TextColumn get exportedPath => text().nullable()();

  /// sha256 of the finished file's bytes, set alongside [localPath] on
  /// [AttachmentTransferState.ready]. Two rows with the same hash share one
  /// physical file — the same photo uploaded under two different R2 keys
  /// (sent by two people, or re-uploaded) costs one copy on disk, not two.
  TextColumn get contentHash => text().nullable()();

  // ─── Reserved for asset encryption. Nothing writes these today. ──────────
  /// Cipher used for the bytes on the wire, '' when stored in the clear.
  TextColumn get cipherAlgo => text().withDefault(const Constant(''))();

  /// Pointer into the E2EE vault — never a raw key.
  TextColumn get cipherKeyRef => text().nullable()();

  /// Plaintext length, when it differs from the transferred ciphertext length.
  IntColumn get plainBytes => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {urlKey};
}

/// Which attachment rows still point at a blob (V5). A refcount edge: a blob
/// is only deleted once no ref remains, and a ref whose message is gone from
/// `cached_messages` is what the orphan sweep looks for.
@TableIndex(name: 'idx_attachment_refs_url', columns: {#urlKey})
@TableIndex(name: 'idx_attachment_refs_message', columns: {#messageId})
class AttachmentRefs extends Table {
  TextColumn get attachmentId => text()();
  TextColumn get urlKey => text()();
  TextColumn get messageId => text()();
  TextColumn get conversationId => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {attachmentId};
}
