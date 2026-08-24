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

class $CachedMessagesTable extends CachedMessages
    with TableInfo<$CachedMessagesTable, CachedMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _threadRootIdMeta = const VerificationMeta(
    'threadRootId',
  );
  @override
  late final GeneratedColumn<String> threadRootId = GeneratedColumn<String>(
    'thread_root_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _searchTextMeta = const VerificationMeta(
    'searchText',
  );
  @override
  late final GeneratedColumn<String> searchText = GeneratedColumn<String>(
    'search_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conversationId,
    createdAtMs,
    threadRootId,
    payloadJson,
    searchText,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    if (data.containsKey('thread_root_id')) {
      context.handle(
        _threadRootIdMeta,
        threadRootId.isAcceptableOrUnknown(
          data['thread_root_id']!,
          _threadRootIdMeta,
        ),
      );
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
    if (data.containsKey('search_text')) {
      context.handle(
        _searchTextMeta,
        searchText.isAcceptableOrUnknown(data['search_text']!, _searchTextMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedMessage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
      threadRootId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thread_root_id'],
      ),
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      searchText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}search_text'],
      )!,
    );
  }

  @override
  $CachedMessagesTable createAlias(String alias) {
    return $CachedMessagesTable(attachedDatabase, alias);
  }
}

class CachedMessage extends DataClass implements Insertable<CachedMessage> {
  final String id;
  final String conversationId;
  final int createdAtMs;
  final String? threadRootId;
  final String payloadJson;

  /// Lowercased plain text, for offline search. Always empty for an encrypted
  /// DM — its plaintext never leaves the vault.
  final String searchText;
  const CachedMessage({
    required this.id,
    required this.conversationId,
    required this.createdAtMs,
    this.threadRootId,
    required this.payloadJson,
    required this.searchText,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['created_at_ms'] = Variable<int>(createdAtMs);
    if (!nullToAbsent || threadRootId != null) {
      map['thread_root_id'] = Variable<String>(threadRootId);
    }
    map['payload_json'] = Variable<String>(payloadJson);
    map['search_text'] = Variable<String>(searchText);
    return map;
  }

  CachedMessagesCompanion toCompanion(bool nullToAbsent) {
    return CachedMessagesCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      createdAtMs: Value(createdAtMs),
      threadRootId: threadRootId == null && nullToAbsent
          ? const Value.absent()
          : Value(threadRootId),
      payloadJson: Value(payloadJson),
      searchText: Value(searchText),
    );
  }

  factory CachedMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedMessage(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
      threadRootId: serializer.fromJson<String?>(json['threadRootId']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      searchText: serializer.fromJson<String>(json['searchText']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
      'threadRootId': serializer.toJson<String?>(threadRootId),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'searchText': serializer.toJson<String>(searchText),
    };
  }

  CachedMessage copyWith({
    String? id,
    String? conversationId,
    int? createdAtMs,
    Value<String?> threadRootId = const Value.absent(),
    String? payloadJson,
    String? searchText,
  }) => CachedMessage(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    createdAtMs: createdAtMs ?? this.createdAtMs,
    threadRootId: threadRootId.present ? threadRootId.value : this.threadRootId,
    payloadJson: payloadJson ?? this.payloadJson,
    searchText: searchText ?? this.searchText,
  );
  CachedMessage copyWithCompanion(CachedMessagesCompanion data) {
    return CachedMessage(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
      threadRootId: data.threadRootId.present
          ? data.threadRootId.value
          : this.threadRootId,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      searchText: data.searchText.present
          ? data.searchText.value
          : this.searchText,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedMessage(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('threadRootId: $threadRootId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('searchText: $searchText')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    conversationId,
    createdAtMs,
    threadRootId,
    payloadJson,
    searchText,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedMessage &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.createdAtMs == this.createdAtMs &&
          other.threadRootId == this.threadRootId &&
          other.payloadJson == this.payloadJson &&
          other.searchText == this.searchText);
}

class CachedMessagesCompanion extends UpdateCompanion<CachedMessage> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<int> createdAtMs;
  final Value<String?> threadRootId;
  final Value<String> payloadJson;
  final Value<String> searchText;
  final Value<int> rowid;
  const CachedMessagesCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.threadRootId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.searchText = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedMessagesCompanion.insert({
    required String id,
    required String conversationId,
    required int createdAtMs,
    this.threadRootId = const Value.absent(),
    required String payloadJson,
    this.searchText = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       conversationId = Value(conversationId),
       createdAtMs = Value(createdAtMs),
       payloadJson = Value(payloadJson);
  static Insertable<CachedMessage> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<int>? createdAtMs,
    Expression<String>? threadRootId,
    Expression<String>? payloadJson,
    Expression<String>? searchText,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (threadRootId != null) 'thread_root_id': threadRootId,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (searchText != null) 'search_text': searchText,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedMessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? conversationId,
    Value<int>? createdAtMs,
    Value<String?>? threadRootId,
    Value<String>? payloadJson,
    Value<String>? searchText,
    Value<int>? rowid,
  }) {
    return CachedMessagesCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      threadRootId: threadRootId ?? this.threadRootId,
      payloadJson: payloadJson ?? this.payloadJson,
      searchText: searchText ?? this.searchText,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (threadRootId.present) {
      map['thread_root_id'] = Variable<String>(threadRootId.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (searchText.present) {
      map['search_text'] = Variable<String>(searchText.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedMessagesCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('threadRootId: $threadRootId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('searchText: $searchText, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingOutboxMessagesTable extends PendingOutboxMessages
    with TableInfo<$PendingOutboxMessagesTable, PendingOutboxMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingOutboxMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientRefMeta = const VerificationMeta(
    'clientRef',
  );
  @override
  late final GeneratedColumn<String> clientRef = GeneratedColumn<String>(
    'client_ref',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attachmentsJsonMeta = const VerificationMeta(
    'attachmentsJson',
  );
  @override
  late final GeneratedColumn<String> attachmentsJson = GeneratedColumn<String>(
    'attachments_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mentionedUserIdsJsonMeta =
      const VerificationMeta('mentionedUserIdsJson');
  @override
  late final GeneratedColumn<String> mentionedUserIdsJson =
      GeneratedColumn<String>(
        'mentioned_user_ids_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _encryptedBodyMeta = const VerificationMeta(
    'encryptedBody',
  );
  @override
  late final GeneratedColumn<String> encryptedBody = GeneratedColumn<String>(
    'encrypted_body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _encryptionNonceMeta = const VerificationMeta(
    'encryptionNonce',
  );
  @override
  late final GeneratedColumn<String> encryptionNonce = GeneratedColumn<String>(
    'encryption_nonce',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _encryptionKeyVersionMeta =
      const VerificationMeta('encryptionKeyVersion');
  @override
  late final GeneratedColumn<int> encryptionKeyVersion = GeneratedColumn<int>(
    'encryption_key_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    clientRef,
    conversationId,
    body,
    parentId,
    attachmentsJson,
    mentionedUserIdsJson,
    createdAtMs,
    encryptedBody,
    encryptionNonce,
    encryptionKeyVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_outbox_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingOutboxMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_ref')) {
      context.handle(
        _clientRefMeta,
        clientRef.isAcceptableOrUnknown(data['client_ref']!, _clientRefMeta),
      );
    } else if (isInserting) {
      context.missing(_clientRefMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('attachments_json')) {
      context.handle(
        _attachmentsJsonMeta,
        attachmentsJson.isAcceptableOrUnknown(
          data['attachments_json']!,
          _attachmentsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_attachmentsJsonMeta);
    }
    if (data.containsKey('mentioned_user_ids_json')) {
      context.handle(
        _mentionedUserIdsJsonMeta,
        mentionedUserIdsJson.isAcceptableOrUnknown(
          data['mentioned_user_ids_json']!,
          _mentionedUserIdsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_mentionedUserIdsJsonMeta);
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    if (data.containsKey('encrypted_body')) {
      context.handle(
        _encryptedBodyMeta,
        encryptedBody.isAcceptableOrUnknown(
          data['encrypted_body']!,
          _encryptedBodyMeta,
        ),
      );
    }
    if (data.containsKey('encryption_nonce')) {
      context.handle(
        _encryptionNonceMeta,
        encryptionNonce.isAcceptableOrUnknown(
          data['encryption_nonce']!,
          _encryptionNonceMeta,
        ),
      );
    }
    if (data.containsKey('encryption_key_version')) {
      context.handle(
        _encryptionKeyVersionMeta,
        encryptionKeyVersion.isAcceptableOrUnknown(
          data['encryption_key_version']!,
          _encryptionKeyVersionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {clientRef};
  @override
  PendingOutboxMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingOutboxMessage(
      clientRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_ref'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      attachmentsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachments_json'],
      )!,
      mentionedUserIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mentioned_user_ids_json'],
      )!,
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
      encryptedBody: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_body'],
      ),
      encryptionNonce: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encryption_nonce'],
      ),
      encryptionKeyVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}encryption_key_version'],
      ),
    );
  }

  @override
  $PendingOutboxMessagesTable createAlias(String alias) {
    return $PendingOutboxMessagesTable(attachedDatabase, alias);
  }
}

class PendingOutboxMessage extends DataClass
    implements Insertable<PendingOutboxMessage> {
  final String clientRef;
  final String conversationId;
  final String body;
  final String? parentId;
  final String attachmentsJson;
  final String mentionedUserIdsJson;
  final int createdAtMs;
  final String? encryptedBody;
  final String? encryptionNonce;
  final int? encryptionKeyVersion;
  const PendingOutboxMessage({
    required this.clientRef,
    required this.conversationId,
    required this.body,
    this.parentId,
    required this.attachmentsJson,
    required this.mentionedUserIdsJson,
    required this.createdAtMs,
    this.encryptedBody,
    this.encryptionNonce,
    this.encryptionKeyVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_ref'] = Variable<String>(clientRef);
    map['conversation_id'] = Variable<String>(conversationId);
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['attachments_json'] = Variable<String>(attachmentsJson);
    map['mentioned_user_ids_json'] = Variable<String>(mentionedUserIdsJson);
    map['created_at_ms'] = Variable<int>(createdAtMs);
    if (!nullToAbsent || encryptedBody != null) {
      map['encrypted_body'] = Variable<String>(encryptedBody);
    }
    if (!nullToAbsent || encryptionNonce != null) {
      map['encryption_nonce'] = Variable<String>(encryptionNonce);
    }
    if (!nullToAbsent || encryptionKeyVersion != null) {
      map['encryption_key_version'] = Variable<int>(encryptionKeyVersion);
    }
    return map;
  }

  PendingOutboxMessagesCompanion toCompanion(bool nullToAbsent) {
    return PendingOutboxMessagesCompanion(
      clientRef: Value(clientRef),
      conversationId: Value(conversationId),
      body: Value(body),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      attachmentsJson: Value(attachmentsJson),
      mentionedUserIdsJson: Value(mentionedUserIdsJson),
      createdAtMs: Value(createdAtMs),
      encryptedBody: encryptedBody == null && nullToAbsent
          ? const Value.absent()
          : Value(encryptedBody),
      encryptionNonce: encryptionNonce == null && nullToAbsent
          ? const Value.absent()
          : Value(encryptionNonce),
      encryptionKeyVersion: encryptionKeyVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(encryptionKeyVersion),
    );
  }

  factory PendingOutboxMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingOutboxMessage(
      clientRef: serializer.fromJson<String>(json['clientRef']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      body: serializer.fromJson<String>(json['body']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      attachmentsJson: serializer.fromJson<String>(json['attachmentsJson']),
      mentionedUserIdsJson: serializer.fromJson<String>(
        json['mentionedUserIdsJson'],
      ),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
      encryptedBody: serializer.fromJson<String?>(json['encryptedBody']),
      encryptionNonce: serializer.fromJson<String?>(json['encryptionNonce']),
      encryptionKeyVersion: serializer.fromJson<int?>(
        json['encryptionKeyVersion'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientRef': serializer.toJson<String>(clientRef),
      'conversationId': serializer.toJson<String>(conversationId),
      'body': serializer.toJson<String>(body),
      'parentId': serializer.toJson<String?>(parentId),
      'attachmentsJson': serializer.toJson<String>(attachmentsJson),
      'mentionedUserIdsJson': serializer.toJson<String>(mentionedUserIdsJson),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
      'encryptedBody': serializer.toJson<String?>(encryptedBody),
      'encryptionNonce': serializer.toJson<String?>(encryptionNonce),
      'encryptionKeyVersion': serializer.toJson<int?>(encryptionKeyVersion),
    };
  }

  PendingOutboxMessage copyWith({
    String? clientRef,
    String? conversationId,
    String? body,
    Value<String?> parentId = const Value.absent(),
    String? attachmentsJson,
    String? mentionedUserIdsJson,
    int? createdAtMs,
    Value<String?> encryptedBody = const Value.absent(),
    Value<String?> encryptionNonce = const Value.absent(),
    Value<int?> encryptionKeyVersion = const Value.absent(),
  }) => PendingOutboxMessage(
    clientRef: clientRef ?? this.clientRef,
    conversationId: conversationId ?? this.conversationId,
    body: body ?? this.body,
    parentId: parentId.present ? parentId.value : this.parentId,
    attachmentsJson: attachmentsJson ?? this.attachmentsJson,
    mentionedUserIdsJson: mentionedUserIdsJson ?? this.mentionedUserIdsJson,
    createdAtMs: createdAtMs ?? this.createdAtMs,
    encryptedBody: encryptedBody.present
        ? encryptedBody.value
        : this.encryptedBody,
    encryptionNonce: encryptionNonce.present
        ? encryptionNonce.value
        : this.encryptionNonce,
    encryptionKeyVersion: encryptionKeyVersion.present
        ? encryptionKeyVersion.value
        : this.encryptionKeyVersion,
  );
  PendingOutboxMessage copyWithCompanion(PendingOutboxMessagesCompanion data) {
    return PendingOutboxMessage(
      clientRef: data.clientRef.present ? data.clientRef.value : this.clientRef,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      body: data.body.present ? data.body.value : this.body,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      attachmentsJson: data.attachmentsJson.present
          ? data.attachmentsJson.value
          : this.attachmentsJson,
      mentionedUserIdsJson: data.mentionedUserIdsJson.present
          ? data.mentionedUserIdsJson.value
          : this.mentionedUserIdsJson,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
      encryptedBody: data.encryptedBody.present
          ? data.encryptedBody.value
          : this.encryptedBody,
      encryptionNonce: data.encryptionNonce.present
          ? data.encryptionNonce.value
          : this.encryptionNonce,
      encryptionKeyVersion: data.encryptionKeyVersion.present
          ? data.encryptionKeyVersion.value
          : this.encryptionKeyVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingOutboxMessage(')
          ..write('clientRef: $clientRef, ')
          ..write('conversationId: $conversationId, ')
          ..write('body: $body, ')
          ..write('parentId: $parentId, ')
          ..write('attachmentsJson: $attachmentsJson, ')
          ..write('mentionedUserIdsJson: $mentionedUserIdsJson, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('encryptedBody: $encryptedBody, ')
          ..write('encryptionNonce: $encryptionNonce, ')
          ..write('encryptionKeyVersion: $encryptionKeyVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    clientRef,
    conversationId,
    body,
    parentId,
    attachmentsJson,
    mentionedUserIdsJson,
    createdAtMs,
    encryptedBody,
    encryptionNonce,
    encryptionKeyVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingOutboxMessage &&
          other.clientRef == this.clientRef &&
          other.conversationId == this.conversationId &&
          other.body == this.body &&
          other.parentId == this.parentId &&
          other.attachmentsJson == this.attachmentsJson &&
          other.mentionedUserIdsJson == this.mentionedUserIdsJson &&
          other.createdAtMs == this.createdAtMs &&
          other.encryptedBody == this.encryptedBody &&
          other.encryptionNonce == this.encryptionNonce &&
          other.encryptionKeyVersion == this.encryptionKeyVersion);
}

class PendingOutboxMessagesCompanion
    extends UpdateCompanion<PendingOutboxMessage> {
  final Value<String> clientRef;
  final Value<String> conversationId;
  final Value<String> body;
  final Value<String?> parentId;
  final Value<String> attachmentsJson;
  final Value<String> mentionedUserIdsJson;
  final Value<int> createdAtMs;
  final Value<String?> encryptedBody;
  final Value<String?> encryptionNonce;
  final Value<int?> encryptionKeyVersion;
  final Value<int> rowid;
  const PendingOutboxMessagesCompanion({
    this.clientRef = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.body = const Value.absent(),
    this.parentId = const Value.absent(),
    this.attachmentsJson = const Value.absent(),
    this.mentionedUserIdsJson = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.encryptedBody = const Value.absent(),
    this.encryptionNonce = const Value.absent(),
    this.encryptionKeyVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingOutboxMessagesCompanion.insert({
    required String clientRef,
    required String conversationId,
    required String body,
    this.parentId = const Value.absent(),
    required String attachmentsJson,
    required String mentionedUserIdsJson,
    required int createdAtMs,
    this.encryptedBody = const Value.absent(),
    this.encryptionNonce = const Value.absent(),
    this.encryptionKeyVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : clientRef = Value(clientRef),
       conversationId = Value(conversationId),
       body = Value(body),
       attachmentsJson = Value(attachmentsJson),
       mentionedUserIdsJson = Value(mentionedUserIdsJson),
       createdAtMs = Value(createdAtMs);
  static Insertable<PendingOutboxMessage> custom({
    Expression<String>? clientRef,
    Expression<String>? conversationId,
    Expression<String>? body,
    Expression<String>? parentId,
    Expression<String>? attachmentsJson,
    Expression<String>? mentionedUserIdsJson,
    Expression<int>? createdAtMs,
    Expression<String>? encryptedBody,
    Expression<String>? encryptionNonce,
    Expression<int>? encryptionKeyVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientRef != null) 'client_ref': clientRef,
      if (conversationId != null) 'conversation_id': conversationId,
      if (body != null) 'body': body,
      if (parentId != null) 'parent_id': parentId,
      if (attachmentsJson != null) 'attachments_json': attachmentsJson,
      if (mentionedUserIdsJson != null)
        'mentioned_user_ids_json': mentionedUserIdsJson,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (encryptedBody != null) 'encrypted_body': encryptedBody,
      if (encryptionNonce != null) 'encryption_nonce': encryptionNonce,
      if (encryptionKeyVersion != null)
        'encryption_key_version': encryptionKeyVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingOutboxMessagesCompanion copyWith({
    Value<String>? clientRef,
    Value<String>? conversationId,
    Value<String>? body,
    Value<String?>? parentId,
    Value<String>? attachmentsJson,
    Value<String>? mentionedUserIdsJson,
    Value<int>? createdAtMs,
    Value<String?>? encryptedBody,
    Value<String?>? encryptionNonce,
    Value<int?>? encryptionKeyVersion,
    Value<int>? rowid,
  }) {
    return PendingOutboxMessagesCompanion(
      clientRef: clientRef ?? this.clientRef,
      conversationId: conversationId ?? this.conversationId,
      body: body ?? this.body,
      parentId: parentId ?? this.parentId,
      attachmentsJson: attachmentsJson ?? this.attachmentsJson,
      mentionedUserIdsJson: mentionedUserIdsJson ?? this.mentionedUserIdsJson,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      encryptedBody: encryptedBody ?? this.encryptedBody,
      encryptionNonce: encryptionNonce ?? this.encryptionNonce,
      encryptionKeyVersion: encryptionKeyVersion ?? this.encryptionKeyVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientRef.present) {
      map['client_ref'] = Variable<String>(clientRef.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (attachmentsJson.present) {
      map['attachments_json'] = Variable<String>(attachmentsJson.value);
    }
    if (mentionedUserIdsJson.present) {
      map['mentioned_user_ids_json'] = Variable<String>(
        mentionedUserIdsJson.value,
      );
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (encryptedBody.present) {
      map['encrypted_body'] = Variable<String>(encryptedBody.value);
    }
    if (encryptionNonce.present) {
      map['encryption_nonce'] = Variable<String>(encryptionNonce.value);
    }
    if (encryptionKeyVersion.present) {
      map['encryption_key_version'] = Variable<int>(encryptionKeyVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingOutboxMessagesCompanion(')
          ..write('clientRef: $clientRef, ')
          ..write('conversationId: $conversationId, ')
          ..write('body: $body, ')
          ..write('parentId: $parentId, ')
          ..write('attachmentsJson: $attachmentsJson, ')
          ..write('mentionedUserIdsJson: $mentionedUserIdsJson, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('encryptedBody: $encryptedBody, ')
          ..write('encryptionNonce: $encryptionNonce, ')
          ..write('encryptionKeyVersion: $encryptionKeyVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ChatLocalDb extends GeneratedDatabase {
  _$ChatLocalDb(QueryExecutor e) : super(e);
  $ChatLocalDbManager get managers => $ChatLocalDbManager(this);
  late final $CachedSidebarsTable cachedSidebars = $CachedSidebarsTable(this);
  late final $CachedMessagesTable cachedMessages = $CachedMessagesTable(this);
  late final $PendingOutboxMessagesTable pendingOutboxMessages =
      $PendingOutboxMessagesTable(this);
  late final Index idxCachedMessagesConvTime = Index(
    'idx_cached_messages_conv_time',
    'CREATE INDEX idx_cached_messages_conv_time ON cached_messages (conversation_id, created_at_ms)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cachedSidebars,
    cachedMessages,
    pendingOutboxMessages,
    idxCachedMessagesConvTime,
  ];
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
typedef $$CachedMessagesTableCreateCompanionBuilder =
    CachedMessagesCompanion Function({
      required String id,
      required String conversationId,
      required int createdAtMs,
      Value<String?> threadRootId,
      required String payloadJson,
      Value<String> searchText,
      Value<int> rowid,
    });
typedef $$CachedMessagesTableUpdateCompanionBuilder =
    CachedMessagesCompanion Function({
      Value<String> id,
      Value<String> conversationId,
      Value<int> createdAtMs,
      Value<String?> threadRootId,
      Value<String> payloadJson,
      Value<String> searchText,
      Value<int> rowid,
    });

class $$CachedMessagesTableFilterComposer
    extends Composer<_$ChatLocalDb, $CachedMessagesTable> {
  $$CachedMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get threadRootId => $composableBuilder(
    column: $table.threadRootId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedMessagesTableOrderingComposer
    extends Composer<_$ChatLocalDb, $CachedMessagesTable> {
  $$CachedMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get threadRootId => $composableBuilder(
    column: $table.threadRootId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedMessagesTableAnnotationComposer
    extends Composer<_$ChatLocalDb, $CachedMessagesTable> {
  $$CachedMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get threadRootId => $composableBuilder(
    column: $table.threadRootId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => column,
  );
}

class $$CachedMessagesTableTableManager
    extends
        RootTableManager<
          _$ChatLocalDb,
          $CachedMessagesTable,
          CachedMessage,
          $$CachedMessagesTableFilterComposer,
          $$CachedMessagesTableOrderingComposer,
          $$CachedMessagesTableAnnotationComposer,
          $$CachedMessagesTableCreateCompanionBuilder,
          $$CachedMessagesTableUpdateCompanionBuilder,
          (
            CachedMessage,
            BaseReferences<_$ChatLocalDb, $CachedMessagesTable, CachedMessage>,
          ),
          CachedMessage,
          PrefetchHooks Function()
        > {
  $$CachedMessagesTableTableManager(
    _$ChatLocalDb db,
    $CachedMessagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<String?> threadRootId = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String> searchText = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedMessagesCompanion(
                id: id,
                conversationId: conversationId,
                createdAtMs: createdAtMs,
                threadRootId: threadRootId,
                payloadJson: payloadJson,
                searchText: searchText,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String conversationId,
                required int createdAtMs,
                Value<String?> threadRootId = const Value.absent(),
                required String payloadJson,
                Value<String> searchText = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedMessagesCompanion.insert(
                id: id,
                conversationId: conversationId,
                createdAtMs: createdAtMs,
                threadRootId: threadRootId,
                payloadJson: payloadJson,
                searchText: searchText,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$ChatLocalDb,
      $CachedMessagesTable,
      CachedMessage,
      $$CachedMessagesTableFilterComposer,
      $$CachedMessagesTableOrderingComposer,
      $$CachedMessagesTableAnnotationComposer,
      $$CachedMessagesTableCreateCompanionBuilder,
      $$CachedMessagesTableUpdateCompanionBuilder,
      (
        CachedMessage,
        BaseReferences<_$ChatLocalDb, $CachedMessagesTable, CachedMessage>,
      ),
      CachedMessage,
      PrefetchHooks Function()
    >;
typedef $$PendingOutboxMessagesTableCreateCompanionBuilder =
    PendingOutboxMessagesCompanion Function({
      required String clientRef,
      required String conversationId,
      required String body,
      Value<String?> parentId,
      required String attachmentsJson,
      required String mentionedUserIdsJson,
      required int createdAtMs,
      Value<String?> encryptedBody,
      Value<String?> encryptionNonce,
      Value<int?> encryptionKeyVersion,
      Value<int> rowid,
    });
typedef $$PendingOutboxMessagesTableUpdateCompanionBuilder =
    PendingOutboxMessagesCompanion Function({
      Value<String> clientRef,
      Value<String> conversationId,
      Value<String> body,
      Value<String?> parentId,
      Value<String> attachmentsJson,
      Value<String> mentionedUserIdsJson,
      Value<int> createdAtMs,
      Value<String?> encryptedBody,
      Value<String?> encryptionNonce,
      Value<int?> encryptionKeyVersion,
      Value<int> rowid,
    });

class $$PendingOutboxMessagesTableFilterComposer
    extends Composer<_$ChatLocalDb, $PendingOutboxMessagesTable> {
  $$PendingOutboxMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientRef => $composableBuilder(
    column: $table.clientRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachmentsJson => $composableBuilder(
    column: $table.attachmentsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mentionedUserIdsJson => $composableBuilder(
    column: $table.mentionedUserIdsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedBody => $composableBuilder(
    column: $table.encryptedBody,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptionNonce => $composableBuilder(
    column: $table.encryptionNonce,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get encryptionKeyVersion => $composableBuilder(
    column: $table.encryptionKeyVersion,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingOutboxMessagesTableOrderingComposer
    extends Composer<_$ChatLocalDb, $PendingOutboxMessagesTable> {
  $$PendingOutboxMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientRef => $composableBuilder(
    column: $table.clientRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachmentsJson => $composableBuilder(
    column: $table.attachmentsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mentionedUserIdsJson => $composableBuilder(
    column: $table.mentionedUserIdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedBody => $composableBuilder(
    column: $table.encryptedBody,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptionNonce => $composableBuilder(
    column: $table.encryptionNonce,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get encryptionKeyVersion => $composableBuilder(
    column: $table.encryptionKeyVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingOutboxMessagesTableAnnotationComposer
    extends Composer<_$ChatLocalDb, $PendingOutboxMessagesTable> {
  $$PendingOutboxMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientRef =>
      $composableBuilder(column: $table.clientRef, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get attachmentsJson => $composableBuilder(
    column: $table.attachmentsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mentionedUserIdsJson => $composableBuilder(
    column: $table.mentionedUserIdsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get encryptedBody => $composableBuilder(
    column: $table.encryptedBody,
    builder: (column) => column,
  );

  GeneratedColumn<String> get encryptionNonce => $composableBuilder(
    column: $table.encryptionNonce,
    builder: (column) => column,
  );

  GeneratedColumn<int> get encryptionKeyVersion => $composableBuilder(
    column: $table.encryptionKeyVersion,
    builder: (column) => column,
  );
}

class $$PendingOutboxMessagesTableTableManager
    extends
        RootTableManager<
          _$ChatLocalDb,
          $PendingOutboxMessagesTable,
          PendingOutboxMessage,
          $$PendingOutboxMessagesTableFilterComposer,
          $$PendingOutboxMessagesTableOrderingComposer,
          $$PendingOutboxMessagesTableAnnotationComposer,
          $$PendingOutboxMessagesTableCreateCompanionBuilder,
          $$PendingOutboxMessagesTableUpdateCompanionBuilder,
          (
            PendingOutboxMessage,
            BaseReferences<
              _$ChatLocalDb,
              $PendingOutboxMessagesTable,
              PendingOutboxMessage
            >,
          ),
          PendingOutboxMessage,
          PrefetchHooks Function()
        > {
  $$PendingOutboxMessagesTableTableManager(
    _$ChatLocalDb db,
    $PendingOutboxMessagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingOutboxMessagesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$PendingOutboxMessagesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PendingOutboxMessagesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> clientRef = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String> attachmentsJson = const Value.absent(),
                Value<String> mentionedUserIdsJson = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<String?> encryptedBody = const Value.absent(),
                Value<String?> encryptionNonce = const Value.absent(),
                Value<int?> encryptionKeyVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingOutboxMessagesCompanion(
                clientRef: clientRef,
                conversationId: conversationId,
                body: body,
                parentId: parentId,
                attachmentsJson: attachmentsJson,
                mentionedUserIdsJson: mentionedUserIdsJson,
                createdAtMs: createdAtMs,
                encryptedBody: encryptedBody,
                encryptionNonce: encryptionNonce,
                encryptionKeyVersion: encryptionKeyVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String clientRef,
                required String conversationId,
                required String body,
                Value<String?> parentId = const Value.absent(),
                required String attachmentsJson,
                required String mentionedUserIdsJson,
                required int createdAtMs,
                Value<String?> encryptedBody = const Value.absent(),
                Value<String?> encryptionNonce = const Value.absent(),
                Value<int?> encryptionKeyVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingOutboxMessagesCompanion.insert(
                clientRef: clientRef,
                conversationId: conversationId,
                body: body,
                parentId: parentId,
                attachmentsJson: attachmentsJson,
                mentionedUserIdsJson: mentionedUserIdsJson,
                createdAtMs: createdAtMs,
                encryptedBody: encryptedBody,
                encryptionNonce: encryptionNonce,
                encryptionKeyVersion: encryptionKeyVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingOutboxMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$ChatLocalDb,
      $PendingOutboxMessagesTable,
      PendingOutboxMessage,
      $$PendingOutboxMessagesTableFilterComposer,
      $$PendingOutboxMessagesTableOrderingComposer,
      $$PendingOutboxMessagesTableAnnotationComposer,
      $$PendingOutboxMessagesTableCreateCompanionBuilder,
      $$PendingOutboxMessagesTableUpdateCompanionBuilder,
      (
        PendingOutboxMessage,
        BaseReferences<
          _$ChatLocalDb,
          $PendingOutboxMessagesTable,
          PendingOutboxMessage
        >,
      ),
      PendingOutboxMessage,
      PrefetchHooks Function()
    >;

class $ChatLocalDbManager {
  final _$ChatLocalDb _db;
  $ChatLocalDbManager(this._db);
  $$CachedSidebarsTableTableManager get cachedSidebars =>
      $$CachedSidebarsTableTableManager(_db, _db.cachedSidebars);
  $$CachedMessagesTableTableManager get cachedMessages =>
      $$CachedMessagesTableTableManager(_db, _db.cachedMessages);
  $$PendingOutboxMessagesTableTableManager get pendingOutboxMessages =>
      $$PendingOutboxMessagesTableTableManager(_db, _db.pendingOutboxMessages);
}
