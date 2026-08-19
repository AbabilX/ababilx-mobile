import 'package:drift/drift.dart';

/// One row per logged-in user — full sidebar JSON blob (V1).
class CachedSidebars extends Table {
  TextColumn get userId => text()();
  TextColumn get payloadJson => text()();
  IntColumn get updatedAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {userId};
}

/// One row per conversation — JSON array of last 50 messages (V2).
/// Pending / failed messages are never written here (only confirmed ones).
class CachedMessageFeeds extends Table {
  TextColumn get conversationId => text()();
  TextColumn get payloadJson => text()();
  IntColumn get updatedAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {conversationId};
}

/// One row per not-yet-confirmed outbound message, so a send that fails (or
/// never gets the chance to try) survives an app restart — like WhatsApp's
/// outbox (V3). Removed once the server confirms the send.
///
/// Channel messages store [body] in plain text. DM messages store the
/// already-sealed [encryptedBody]/[encryptionNonce]/[encryptionKeyVersion]
/// instead and leave [body] empty — the same "ciphertext only at rest" rule
/// [CachedMessageFeeds] follows, so a failed DM send is durable without ever
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
