// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_local_db.dart';

// ignore_for_file: type=lint
class $CachedSidebarsTable extends CachedSidebars
    with TableInfo<$CachedSidebarsTable, CachedSidebar> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedSidebarsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMsMeta = const VerificationMeta(
    'updatedAtMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtMs = GeneratedColumn<int>(
    'updated_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [userId, payloadJson, updatedAtMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_sidebars';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedSidebar> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('updated_at_ms')) {
      context.handle(
        _updatedAtMsMeta,
        updatedAtMs.isAcceptableOrUnknown(
          data['updated_at_ms']!,
          _updatedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId};
  @override
  CachedSidebar map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedSidebar(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      updatedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_ms'],
      )!,
    );
  }

  @override
  $CachedSidebarsTable createAlias(String alias) {
    return $CachedSidebarsTable(attachedDatabase, alias);
  }
}

class CachedSidebar extends DataClass implements Insertable<CachedSidebar> {
  final String userId;
  final String payloadJson;
  final int updatedAtMs;
  const CachedSidebar({
    required this.userId,
    required this.payloadJson,
    required this.updatedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['payload_json'] = Variable<String>(payloadJson);
    map['updated_at_ms'] = Variable<int>(updatedAtMs);
    return map;
  }

  CachedSidebarsCompanion toCompanion(bool nullToAbsent) {
    return CachedSidebarsCompanion(
      userId: Value(userId),
      payloadJson: Value(payloadJson),
      updatedAtMs: Value(updatedAtMs),
    );
  }

  factory CachedSidebar.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedSidebar(
      userId: serializer.fromJson<String>(json['userId']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      updatedAtMs: serializer.fromJson<int>(json['updatedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'updatedAtMs': serializer.toJson<int>(updatedAtMs),
    };
  }

  CachedSidebar copyWith({
    String? userId,
    String? payloadJson,
    int? updatedAtMs,
  }) => CachedSidebar(
    userId: userId ?? this.userId,
    payloadJson: payloadJson ?? this.payloadJson,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
  );
  CachedSidebar copyWithCompanion(CachedSidebarsCompanion data) {
    return CachedSidebar(
      userId: data.userId.present ? data.userId.value : this.userId,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      updatedAtMs: data.updatedAtMs.present
          ? data.updatedAtMs.value
          : this.updatedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedSidebar(')
          ..write('userId: $userId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAtMs: $updatedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, payloadJson, updatedAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedSidebar &&
          other.userId == this.userId &&
          other.payloadJson == this.payloadJson &&
          other.updatedAtMs == this.updatedAtMs);
}

class CachedSidebarsCompanion extends UpdateCompanion<CachedSidebar> {
  final Value<String> userId;
  final Value<String> payloadJson;
  final Value<int> updatedAtMs;
  final Value<int> rowid;
  const CachedSidebarsCompanion({
    this.userId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.updatedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedSidebarsCompanion.insert({
    required String userId,
    required String payloadJson,
    required int updatedAtMs,
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       payloadJson = Value(payloadJson),
       updatedAtMs = Value(updatedAtMs);
  static Insertable<CachedSidebar> custom({
    Expression<String>? userId,
    Expression<String>? payloadJson,
    Expression<int>? updatedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (updatedAtMs != null) 'updated_at_ms': updatedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedSidebarsCompanion copyWith({
    Value<String>? userId,
    Value<String>? payloadJson,
    Value<int>? updatedAtMs,
    Value<int>? rowid,
  }) {
    return CachedSidebarsCompanion(
      userId: userId ?? this.userId,
      payloadJson: payloadJson ?? this.payloadJson,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (updatedAtMs.present) {
      map['updated_at_ms'] = Variable<int>(updatedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedSidebarsCompanion(')
          ..write('userId: $userId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ChatLocalDb extends GeneratedDatabase {
  _$ChatLocalDb(QueryExecutor e) : super(e);
  $ChatLocalDbManager get managers => $ChatLocalDbManager(this);
  late final $CachedSidebarsTable cachedSidebars = $CachedSidebarsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [cachedSidebars];
}

typedef $$CachedSidebarsTableCreateCompanionBuilder =
    CachedSidebarsCompanion Function({
      required String userId,
      required String payloadJson,
      required int updatedAtMs,
      Value<int> rowid,
    });
typedef $$CachedSidebarsTableUpdateCompanionBuilder =
    CachedSidebarsCompanion Function({
      Value<String> userId,
      Value<String> payloadJson,
      Value<int> updatedAtMs,
      Value<int> rowid,
    });

class $$CachedSidebarsTableFilterComposer
    extends Composer<_$ChatLocalDb, $CachedSidebarsTable> {
  $$CachedSidebarsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedSidebarsTableOrderingComposer
    extends Composer<_$ChatLocalDb, $CachedSidebarsTable> {
  $$CachedSidebarsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedSidebarsTableAnnotationComposer
    extends Composer<_$ChatLocalDb, $CachedSidebarsTable> {
  $$CachedSidebarsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => column,
  );
}

class $$CachedSidebarsTableTableManager
    extends
        RootTableManager<
          _$ChatLocalDb,
          $CachedSidebarsTable,
          CachedSidebar,
          $$CachedSidebarsTableFilterComposer,
          $$CachedSidebarsTableOrderingComposer,
          $$CachedSidebarsTableAnnotationComposer,
          $$CachedSidebarsTableCreateCompanionBuilder,
          $$CachedSidebarsTableUpdateCompanionBuilder,
          (
            CachedSidebar,
            BaseReferences<_$ChatLocalDb, $CachedSidebarsTable, CachedSidebar>,
          ),
          CachedSidebar,
          PrefetchHooks Function()
        > {
  $$CachedSidebarsTableTableManager(
    _$ChatLocalDb db,
    $CachedSidebarsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedSidebarsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedSidebarsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedSidebarsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<int> updatedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedSidebarsCompanion(
                userId: userId,
                payloadJson: payloadJson,
                updatedAtMs: updatedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required String payloadJson,
                required int updatedAtMs,
                Value<int> rowid = const Value.absent(),
              }) => CachedSidebarsCompanion.insert(
                userId: userId,
                payloadJson: payloadJson,
                updatedAtMs: updatedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedSidebarsTableProcessedTableManager =
    ProcessedTableManager<
      _$ChatLocalDb,
      $CachedSidebarsTable,
      CachedSidebar,
      $$CachedSidebarsTableFilterComposer,
      $$CachedSidebarsTableOrderingComposer,
      $$CachedSidebarsTableAnnotationComposer,
      $$CachedSidebarsTableCreateCompanionBuilder,
      $$CachedSidebarsTableUpdateCompanionBuilder,
      (
        CachedSidebar,
        BaseReferences<_$ChatLocalDb, $CachedSidebarsTable, CachedSidebar>,
      ),
      CachedSidebar,
      PrefetchHooks Function()
    >;

class $ChatLocalDbManager {
  final _$ChatLocalDb _db;
  $ChatLocalDbManager(this._db);
  $$CachedSidebarsTableTableManager get cachedSidebars =>
      $$CachedSidebarsTableTableManager(_db, _db.cachedSidebars);
}
