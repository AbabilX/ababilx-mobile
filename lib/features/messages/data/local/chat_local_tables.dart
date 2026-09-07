import 'package:drift/drift.dart';

/// One row per logged-in user — full sidebar JSON blob (V1).
class CachedSidebars extends Table {
  TextColumn get userId => text()();
  TextColumn get payloadJson => text()();
  IntColumn get updatedAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {userId};
}

/// One row per message — the durable chat history (V4). Replaces the old
/// "last 50 messages as one JSON blob per conversation" cache: paging, search
/// and every offline read are indexed queries over this table, so history stays
/// browsable with no network and no ceiling other than [pruneKeepPerConversation],
/// which is a runaway backstop rather than a retention window.
///
/// [payloadJson] is the full server message JSON. For an E2EE DM its `body` is
/// blanked and only the ciphertext fields are kept — the same "ciphertext only
/// at rest" rule the rest of the local layer follows.
@TableIndex(
  name: 'idx_cached_messages_conv_time',
  columns: {#conversationId, #createdAtMs},
)
class CachedMessages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text()();
  IntColumn get createdAtMs => integer()();
  TextColumn get threadRootId => text().nullable()();
  TextColumn get payloadJson => text()();

  /// Lowercased plain text, for offline search. Always empty for an encrypted
  /// DM — its plaintext never leaves the vault.
  TextColumn get searchText => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One row per not-yet-confirmed outbound message, so a send that fails (or
/// never gets the chance to try) survives an app restart — like WhatsApp's
/// outbox (V3). Removed once the server confirms the send.
///
/// Channel messages store [body] in plain text. DM messages store the
/// already-sealed [encryptedBody]/[encryptionNonce]/[encryptionKeyVersion]
/// instead and leave [body] empty — the same "ciphertext only at rest" rule
/// [CachedMessages] follows, so a failed DM send is durable without ever
/// putting plaintext on disk outside the PIN-controlled vault.
class PendingOutboxMessages extends Table {
  TextColumn get clientRef => text()();
  TextColumn get conversationId => text()();
  TextColumn get body => text()();
  TextColumn get parentId => text().nullable()();
  TextColumn get attachmentsJson => text()();
  TextColumn get mentionedUserIdsJson => text()();
  IntColumn get createdAtMs => integer()();
  TextColumn get encryptedBody => text().nullable()();
  TextColumn get encryptionNonce => text().nullable()();
  IntColumn get encryptionKeyVersion => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {clientRef};
}
