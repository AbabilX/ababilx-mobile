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
