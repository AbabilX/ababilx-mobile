import 'package:drift/drift.dart';

/// One row per logged-in user — full sidebar JSON blob (V1).
/// Messages / team tables land in later schema versions.
class CachedSidebars extends Table {
  TextColumn get userId => text()();
  TextColumn get payloadJson => text()();
  IntColumn get updatedAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {userId};
}
