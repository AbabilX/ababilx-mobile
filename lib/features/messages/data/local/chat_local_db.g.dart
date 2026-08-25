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

class $AttachmentBlobsTable extends AttachmentBlobs
    with TableInfo<$AttachmentBlobsTable, AttachmentBlob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttachmentBlobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _urlKeyMeta = const VerificationMeta('urlKey');
  @override
  late final GeneratedColumn<String> urlKey = GeneratedColumn<String>(
    'url_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteUrlMeta = const VerificationMeta(
    'remoteUrl',
  );
  @override
  late final GeneratedColumn<String> remoteUrl = GeneratedColumn<String>(
    'remote_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _contentTypeMeta = const VerificationMeta(
    'contentType',
  );
  @override
  late final GeneratedColumn<String> contentType = GeneratedColumn<String>(
    'content_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _expectedBytesMeta = const VerificationMeta(
    'expectedBytes',
  );
  @override
  late final GeneratedColumn<int> expectedBytes = GeneratedColumn<int>(
    'expected_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _receivedBytesMeta = const VerificationMeta(
    'receivedBytes',
  );
  @override
  late final GeneratedColumn<int> receivedBytes = GeneratedColumn<int>(
    'received_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _transferStateMeta = const VerificationMeta(
    'transferState',
  );
  @override
  late final GeneratedColumn<int> transferState = GeneratedColumn<int>(
    'transfer_state',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _downloadedAtMsMeta = const VerificationMeta(
    'downloadedAtMs',
  );
  @override
  late final GeneratedColumn<int> downloadedAtMs = GeneratedColumn<int>(
    'downloaded_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastAccessMsMeta = const VerificationMeta(
    'lastAccessMs',
  );
  @override
  late final GeneratedColumn<int> lastAccessMs = GeneratedColumn<int>(
    'last_access_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _exportedAtMsMeta = const VerificationMeta(
    'exportedAtMs',
  );
  @override
  late final GeneratedColumn<int> exportedAtMs = GeneratedColumn<int>(
    'exported_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _exportedPathMeta = const VerificationMeta(
    'exportedPath',
  );
  @override
  late final GeneratedColumn<String> exportedPath = GeneratedColumn<String>(
    'exported_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cipherAlgoMeta = const VerificationMeta(
    'cipherAlgo',
  );
  @override
  late final GeneratedColumn<String> cipherAlgo = GeneratedColumn<String>(
    'cipher_algo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _cipherKeyRefMeta = const VerificationMeta(
    'cipherKeyRef',
  );
  @override
  late final GeneratedColumn<String> cipherKeyRef = GeneratedColumn<String>(
    'cipher_key_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plainBytesMeta = const VerificationMeta(
    'plainBytes',
  );
  @override
  late final GeneratedColumn<int> plainBytes = GeneratedColumn<int>(
    'plain_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    urlKey,
    remoteUrl,
    localPath,
    fileName,
    contentType,
    expectedBytes,
    receivedBytes,
    transferState,
    attempts,
    lastError,
    downloadedAtMs,
    lastAccessMs,
    exportedAtMs,
    exportedPath,
    cipherAlgo,
    cipherKeyRef,
    plainBytes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attachment_blobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<AttachmentBlob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('url_key')) {
      context.handle(
        _urlKeyMeta,
        urlKey.isAcceptableOrUnknown(data['url_key']!, _urlKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_urlKeyMeta);
    }
    if (data.containsKey('remote_url')) {
      context.handle(
        _remoteUrlMeta,
        remoteUrl.isAcceptableOrUnknown(data['remote_url']!, _remoteUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_remoteUrlMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    }
    if (data.containsKey('content_type')) {
      context.handle(
        _contentTypeMeta,
        contentType.isAcceptableOrUnknown(
          data['content_type']!,
          _contentTypeMeta,
        ),
      );
    }
    if (data.containsKey('expected_bytes')) {
      context.handle(
        _expectedBytesMeta,
        expectedBytes.isAcceptableOrUnknown(
          data['expected_bytes']!,
          _expectedBytesMeta,
        ),
      );
    }
    if (data.containsKey('received_bytes')) {
      context.handle(
        _receivedBytesMeta,
        receivedBytes.isAcceptableOrUnknown(
          data['received_bytes']!,
          _receivedBytesMeta,
        ),
      );
    }
    if (data.containsKey('transfer_state')) {
      context.handle(
        _transferStateMeta,
        transferState.isAcceptableOrUnknown(
          data['transfer_state']!,
          _transferStateMeta,
        ),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('downloaded_at_ms')) {
      context.handle(
        _downloadedAtMsMeta,
        downloadedAtMs.isAcceptableOrUnknown(
          data['downloaded_at_ms']!,
          _downloadedAtMsMeta,
        ),
      );
    }
    if (data.containsKey('last_access_ms')) {
      context.handle(
        _lastAccessMsMeta,
        lastAccessMs.isAcceptableOrUnknown(
          data['last_access_ms']!,
          _lastAccessMsMeta,
        ),
      );
    }
    if (data.containsKey('exported_at_ms')) {
      context.handle(
        _exportedAtMsMeta,
        exportedAtMs.isAcceptableOrUnknown(
          data['exported_at_ms']!,
          _exportedAtMsMeta,
        ),
      );
    }
    if (data.containsKey('exported_path')) {
      context.handle(
        _exportedPathMeta,
        exportedPath.isAcceptableOrUnknown(
          data['exported_path']!,
          _exportedPathMeta,
        ),
      );
    }
    if (data.containsKey('cipher_algo')) {
      context.handle(
        _cipherAlgoMeta,
        cipherAlgo.isAcceptableOrUnknown(data['cipher_algo']!, _cipherAlgoMeta),
      );
    }
    if (data.containsKey('cipher_key_ref')) {
      context.handle(
        _cipherKeyRefMeta,
        cipherKeyRef.isAcceptableOrUnknown(
          data['cipher_key_ref']!,
          _cipherKeyRefMeta,
        ),
      );
    }
    if (data.containsKey('plain_bytes')) {
      context.handle(
        _plainBytesMeta,
        plainBytes.isAcceptableOrUnknown(data['plain_bytes']!, _plainBytesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {urlKey};
  @override
  AttachmentBlob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttachmentBlob(
      urlKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url_key'],
      )!,
      remoteUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_url'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      contentType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_type'],
      )!,
      expectedBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expected_bytes'],
      )!,
      receivedBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}received_bytes'],
      )!,
      transferState: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}transfer_state'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      )!,
      downloadedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}downloaded_at_ms'],
      ),
      lastAccessMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_access_ms'],
      )!,
      exportedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}exported_at_ms'],
      ),
      exportedPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exported_path'],
      ),
      cipherAlgo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cipher_algo'],
      )!,
      cipherKeyRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cipher_key_ref'],
      ),
      plainBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}plain_bytes'],
      ),
    );
  }

  @override
  $AttachmentBlobsTable createAlias(String alias) {
    return $AttachmentBlobsTable(attachedDatabase, alias);
  }
}

class AttachmentBlob extends DataClass implements Insertable<AttachmentBlob> {
  final String urlKey;
  final String remoteUrl;

  /// Absolute path of the finished file. Null unless the row is ready.
  final String? localPath;
  final String fileName;
  final String contentType;

  /// Server-verified `size_bytes`. 0 when the message predates verification.
  final int expectedBytes;

  /// Length of the sticky `.part` file — what a resumed request ranges from.
  final int receivedBytes;

  /// [AttachmentTransferState.index]. Stored as a raw int so adding a state
  /// later is not a migration.
  final int transferState;
  final int attempts;
  final String lastError;
  final int? downloadedAtMs;

  /// Drives LRU eviction once the disk budget is exceeded.
  final int lastAccessMs;
  final int? exportedAtMs;
  final String? exportedPath;

  /// Cipher used for the bytes on the wire, '' when stored in the clear.
  final String cipherAlgo;

  /// Pointer into the E2EE vault — never a raw key.
  final String? cipherKeyRef;

  /// Plaintext length, when it differs from the transferred ciphertext length.
  final int? plainBytes;
  const AttachmentBlob({
    required this.urlKey,
    required this.remoteUrl,
    this.localPath,
    required this.fileName,
    required this.contentType,
    required this.expectedBytes,
    required this.receivedBytes,
    required this.transferState,
    required this.attempts,
    required this.lastError,
    this.downloadedAtMs,
    required this.lastAccessMs,
    this.exportedAtMs,
    this.exportedPath,
    required this.cipherAlgo,
    this.cipherKeyRef,
    this.plainBytes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['url_key'] = Variable<String>(urlKey);
    map['remote_url'] = Variable<String>(remoteUrl);
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    map['file_name'] = Variable<String>(fileName);
    map['content_type'] = Variable<String>(contentType);
    map['expected_bytes'] = Variable<int>(expectedBytes);
    map['received_bytes'] = Variable<int>(receivedBytes);
    map['transfer_state'] = Variable<int>(transferState);
    map['attempts'] = Variable<int>(attempts);
    map['last_error'] = Variable<String>(lastError);
    if (!nullToAbsent || downloadedAtMs != null) {
      map['downloaded_at_ms'] = Variable<int>(downloadedAtMs);
    }
    map['last_access_ms'] = Variable<int>(lastAccessMs);
    if (!nullToAbsent || exportedAtMs != null) {
      map['exported_at_ms'] = Variable<int>(exportedAtMs);
    }
    if (!nullToAbsent || exportedPath != null) {
      map['exported_path'] = Variable<String>(exportedPath);
    }
    map['cipher_algo'] = Variable<String>(cipherAlgo);
    if (!nullToAbsent || cipherKeyRef != null) {
      map['cipher_key_ref'] = Variable<String>(cipherKeyRef);
    }
    if (!nullToAbsent || plainBytes != null) {
      map['plain_bytes'] = Variable<int>(plainBytes);
    }
    return map;
  }

  AttachmentBlobsCompanion toCompanion(bool nullToAbsent) {
    return AttachmentBlobsCompanion(
      urlKey: Value(urlKey),
      remoteUrl: Value(remoteUrl),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      fileName: Value(fileName),
      contentType: Value(contentType),
      expectedBytes: Value(expectedBytes),
      receivedBytes: Value(receivedBytes),
      transferState: Value(transferState),
      attempts: Value(attempts),
      lastError: Value(lastError),
      downloadedAtMs: downloadedAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(downloadedAtMs),
      lastAccessMs: Value(lastAccessMs),
      exportedAtMs: exportedAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(exportedAtMs),
      exportedPath: exportedPath == null && nullToAbsent
          ? const Value.absent()
          : Value(exportedPath),
      cipherAlgo: Value(cipherAlgo),
      cipherKeyRef: cipherKeyRef == null && nullToAbsent
          ? const Value.absent()
          : Value(cipherKeyRef),
      plainBytes: plainBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(plainBytes),
    );
  }

  factory AttachmentBlob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttachmentBlob(
      urlKey: serializer.fromJson<String>(json['urlKey']),
      remoteUrl: serializer.fromJson<String>(json['remoteUrl']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      fileName: serializer.fromJson<String>(json['fileName']),
      contentType: serializer.fromJson<String>(json['contentType']),
      expectedBytes: serializer.fromJson<int>(json['expectedBytes']),
      receivedBytes: serializer.fromJson<int>(json['receivedBytes']),
      transferState: serializer.fromJson<int>(json['transferState']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String>(json['lastError']),
      downloadedAtMs: serializer.fromJson<int?>(json['downloadedAtMs']),
      lastAccessMs: serializer.fromJson<int>(json['lastAccessMs']),
      exportedAtMs: serializer.fromJson<int?>(json['exportedAtMs']),
      exportedPath: serializer.fromJson<String?>(json['exportedPath']),
      cipherAlgo: serializer.fromJson<String>(json['cipherAlgo']),
      cipherKeyRef: serializer.fromJson<String?>(json['cipherKeyRef']),
      plainBytes: serializer.fromJson<int?>(json['plainBytes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'urlKey': serializer.toJson<String>(urlKey),
      'remoteUrl': serializer.toJson<String>(remoteUrl),
      'localPath': serializer.toJson<String?>(localPath),
      'fileName': serializer.toJson<String>(fileName),
      'contentType': serializer.toJson<String>(contentType),
      'expectedBytes': serializer.toJson<int>(expectedBytes),
      'receivedBytes': serializer.toJson<int>(receivedBytes),
      'transferState': serializer.toJson<int>(transferState),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String>(lastError),
      'downloadedAtMs': serializer.toJson<int?>(downloadedAtMs),
      'lastAccessMs': serializer.toJson<int>(lastAccessMs),
      'exportedAtMs': serializer.toJson<int?>(exportedAtMs),
      'exportedPath': serializer.toJson<String?>(exportedPath),
      'cipherAlgo': serializer.toJson<String>(cipherAlgo),
      'cipherKeyRef': serializer.toJson<String?>(cipherKeyRef),
      'plainBytes': serializer.toJson<int?>(plainBytes),
    };
  }

  AttachmentBlob copyWith({
    String? urlKey,
    String? remoteUrl,
    Value<String?> localPath = const Value.absent(),
    String? fileName,
    String? contentType,
    int? expectedBytes,
    int? receivedBytes,
    int? transferState,
    int? attempts,
    String? lastError,
    Value<int?> downloadedAtMs = const Value.absent(),
    int? lastAccessMs,
    Value<int?> exportedAtMs = const Value.absent(),
    Value<String?> exportedPath = const Value.absent(),
    String? cipherAlgo,
    Value<String?> cipherKeyRef = const Value.absent(),
    Value<int?> plainBytes = const Value.absent(),
  }) => AttachmentBlob(
    urlKey: urlKey ?? this.urlKey,
    remoteUrl: remoteUrl ?? this.remoteUrl,
    localPath: localPath.present ? localPath.value : this.localPath,
    fileName: fileName ?? this.fileName,
    contentType: contentType ?? this.contentType,
    expectedBytes: expectedBytes ?? this.expectedBytes,
    receivedBytes: receivedBytes ?? this.receivedBytes,
    transferState: transferState ?? this.transferState,
    attempts: attempts ?? this.attempts,
    lastError: lastError ?? this.lastError,
    downloadedAtMs: downloadedAtMs.present
        ? downloadedAtMs.value
        : this.downloadedAtMs,
    lastAccessMs: lastAccessMs ?? this.lastAccessMs,
    exportedAtMs: exportedAtMs.present ? exportedAtMs.value : this.exportedAtMs,
    exportedPath: exportedPath.present ? exportedPath.value : this.exportedPath,
    cipherAlgo: cipherAlgo ?? this.cipherAlgo,
    cipherKeyRef: cipherKeyRef.present ? cipherKeyRef.value : this.cipherKeyRef,
    plainBytes: plainBytes.present ? plainBytes.value : this.plainBytes,
  );
  AttachmentBlob copyWithCompanion(AttachmentBlobsCompanion data) {
    return AttachmentBlob(
      urlKey: data.urlKey.present ? data.urlKey.value : this.urlKey,
      remoteUrl: data.remoteUrl.present ? data.remoteUrl.value : this.remoteUrl,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      contentType: data.contentType.present
          ? data.contentType.value
          : this.contentType,
      expectedBytes: data.expectedBytes.present
          ? data.expectedBytes.value
          : this.expectedBytes,
      receivedBytes: data.receivedBytes.present
          ? data.receivedBytes.value
          : this.receivedBytes,
      transferState: data.transferState.present
          ? data.transferState.value
          : this.transferState,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      downloadedAtMs: data.downloadedAtMs.present
          ? data.downloadedAtMs.value
          : this.downloadedAtMs,
      lastAccessMs: data.lastAccessMs.present
          ? data.lastAccessMs.value
          : this.lastAccessMs,
      exportedAtMs: data.exportedAtMs.present
          ? data.exportedAtMs.value
          : this.exportedAtMs,
      exportedPath: data.exportedPath.present
          ? data.exportedPath.value
          : this.exportedPath,
      cipherAlgo: data.cipherAlgo.present
          ? data.cipherAlgo.value
          : this.cipherAlgo,
      cipherKeyRef: data.cipherKeyRef.present
          ? data.cipherKeyRef.value
          : this.cipherKeyRef,
      plainBytes: data.plainBytes.present
          ? data.plainBytes.value
          : this.plainBytes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentBlob(')
          ..write('urlKey: $urlKey, ')
          ..write('remoteUrl: $remoteUrl, ')
          ..write('localPath: $localPath, ')
          ..write('fileName: $fileName, ')
          ..write('contentType: $contentType, ')
          ..write('expectedBytes: $expectedBytes, ')
          ..write('receivedBytes: $receivedBytes, ')
          ..write('transferState: $transferState, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('downloadedAtMs: $downloadedAtMs, ')
          ..write('lastAccessMs: $lastAccessMs, ')
          ..write('exportedAtMs: $exportedAtMs, ')
          ..write('exportedPath: $exportedPath, ')
          ..write('cipherAlgo: $cipherAlgo, ')
          ..write('cipherKeyRef: $cipherKeyRef, ')
          ..write('plainBytes: $plainBytes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    urlKey,
    remoteUrl,
    localPath,
    fileName,
    contentType,
    expectedBytes,
    receivedBytes,
    transferState,
    attempts,
    lastError,
    downloadedAtMs,
    lastAccessMs,
    exportedAtMs,
    exportedPath,
    cipherAlgo,
    cipherKeyRef,
    plainBytes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttachmentBlob &&
          other.urlKey == this.urlKey &&
          other.remoteUrl == this.remoteUrl &&
          other.localPath == this.localPath &&
          other.fileName == this.fileName &&
          other.contentType == this.contentType &&
          other.expectedBytes == this.expectedBytes &&
          other.receivedBytes == this.receivedBytes &&
          other.transferState == this.transferState &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError &&
          other.downloadedAtMs == this.downloadedAtMs &&
          other.lastAccessMs == this.lastAccessMs &&
          other.exportedAtMs == this.exportedAtMs &&
          other.exportedPath == this.exportedPath &&
          other.cipherAlgo == this.cipherAlgo &&
          other.cipherKeyRef == this.cipherKeyRef &&
          other.plainBytes == this.plainBytes);
}

class AttachmentBlobsCompanion extends UpdateCompanion<AttachmentBlob> {
  final Value<String> urlKey;
  final Value<String> remoteUrl;
  final Value<String?> localPath;
  final Value<String> fileName;
  final Value<String> contentType;
  final Value<int> expectedBytes;
  final Value<int> receivedBytes;
  final Value<int> transferState;
  final Value<int> attempts;
  final Value<String> lastError;
  final Value<int?> downloadedAtMs;
  final Value<int> lastAccessMs;
  final Value<int?> exportedAtMs;
  final Value<String?> exportedPath;
  final Value<String> cipherAlgo;
  final Value<String?> cipherKeyRef;
  final Value<int?> plainBytes;
  final Value<int> rowid;
  const AttachmentBlobsCompanion({
    this.urlKey = const Value.absent(),
    this.remoteUrl = const Value.absent(),
    this.localPath = const Value.absent(),
    this.fileName = const Value.absent(),
    this.contentType = const Value.absent(),
    this.expectedBytes = const Value.absent(),
    this.receivedBytes = const Value.absent(),
    this.transferState = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.downloadedAtMs = const Value.absent(),
    this.lastAccessMs = const Value.absent(),
    this.exportedAtMs = const Value.absent(),
    this.exportedPath = const Value.absent(),
    this.cipherAlgo = const Value.absent(),
    this.cipherKeyRef = const Value.absent(),
    this.plainBytes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttachmentBlobsCompanion.insert({
    required String urlKey,
    required String remoteUrl,
    this.localPath = const Value.absent(),
    this.fileName = const Value.absent(),
    this.contentType = const Value.absent(),
    this.expectedBytes = const Value.absent(),
    this.receivedBytes = const Value.absent(),
    this.transferState = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.downloadedAtMs = const Value.absent(),
    this.lastAccessMs = const Value.absent(),
    this.exportedAtMs = const Value.absent(),
    this.exportedPath = const Value.absent(),
    this.cipherAlgo = const Value.absent(),
    this.cipherKeyRef = const Value.absent(),
    this.plainBytes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : urlKey = Value(urlKey),
       remoteUrl = Value(remoteUrl);
  static Insertable<AttachmentBlob> custom({
    Expression<String>? urlKey,
    Expression<String>? remoteUrl,
    Expression<String>? localPath,
    Expression<String>? fileName,
    Expression<String>? contentType,
    Expression<int>? expectedBytes,
    Expression<int>? receivedBytes,
    Expression<int>? transferState,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<int>? downloadedAtMs,
    Expression<int>? lastAccessMs,
    Expression<int>? exportedAtMs,
    Expression<String>? exportedPath,
    Expression<String>? cipherAlgo,
    Expression<String>? cipherKeyRef,
    Expression<int>? plainBytes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (urlKey != null) 'url_key': urlKey,
      if (remoteUrl != null) 'remote_url': remoteUrl,
      if (localPath != null) 'local_path': localPath,
      if (fileName != null) 'file_name': fileName,
      if (contentType != null) 'content_type': contentType,
      if (expectedBytes != null) 'expected_bytes': expectedBytes,
      if (receivedBytes != null) 'received_bytes': receivedBytes,
      if (transferState != null) 'transfer_state': transferState,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (downloadedAtMs != null) 'downloaded_at_ms': downloadedAtMs,
      if (lastAccessMs != null) 'last_access_ms': lastAccessMs,
      if (exportedAtMs != null) 'exported_at_ms': exportedAtMs,
      if (exportedPath != null) 'exported_path': exportedPath,
      if (cipherAlgo != null) 'cipher_algo': cipherAlgo,
      if (cipherKeyRef != null) 'cipher_key_ref': cipherKeyRef,
      if (plainBytes != null) 'plain_bytes': plainBytes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttachmentBlobsCompanion copyWith({
    Value<String>? urlKey,
    Value<String>? remoteUrl,
    Value<String?>? localPath,
    Value<String>? fileName,
    Value<String>? contentType,
    Value<int>? expectedBytes,
    Value<int>? receivedBytes,
    Value<int>? transferState,
    Value<int>? attempts,
    Value<String>? lastError,
    Value<int?>? downloadedAtMs,
    Value<int>? lastAccessMs,
    Value<int?>? exportedAtMs,
    Value<String?>? exportedPath,
    Value<String>? cipherAlgo,
    Value<String?>? cipherKeyRef,
    Value<int?>? plainBytes,
    Value<int>? rowid,
  }) {
    return AttachmentBlobsCompanion(
      urlKey: urlKey ?? this.urlKey,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      localPath: localPath ?? this.localPath,
      fileName: fileName ?? this.fileName,
      contentType: contentType ?? this.contentType,
      expectedBytes: expectedBytes ?? this.expectedBytes,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      transferState: transferState ?? this.transferState,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      downloadedAtMs: downloadedAtMs ?? this.downloadedAtMs,
      lastAccessMs: lastAccessMs ?? this.lastAccessMs,
      exportedAtMs: exportedAtMs ?? this.exportedAtMs,
      exportedPath: exportedPath ?? this.exportedPath,
      cipherAlgo: cipherAlgo ?? this.cipherAlgo,
      cipherKeyRef: cipherKeyRef ?? this.cipherKeyRef,
      plainBytes: plainBytes ?? this.plainBytes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (urlKey.present) {
      map['url_key'] = Variable<String>(urlKey.value);
    }
    if (remoteUrl.present) {
      map['remote_url'] = Variable<String>(remoteUrl.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (contentType.present) {
      map['content_type'] = Variable<String>(contentType.value);
    }
    if (expectedBytes.present) {
      map['expected_bytes'] = Variable<int>(expectedBytes.value);
    }
    if (receivedBytes.present) {
      map['received_bytes'] = Variable<int>(receivedBytes.value);
    }
    if (transferState.present) {
      map['transfer_state'] = Variable<int>(transferState.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (downloadedAtMs.present) {
      map['downloaded_at_ms'] = Variable<int>(downloadedAtMs.value);
    }
    if (lastAccessMs.present) {
      map['last_access_ms'] = Variable<int>(lastAccessMs.value);
    }
    if (exportedAtMs.present) {
      map['exported_at_ms'] = Variable<int>(exportedAtMs.value);
    }
    if (exportedPath.present) {
      map['exported_path'] = Variable<String>(exportedPath.value);
    }
    if (cipherAlgo.present) {
      map['cipher_algo'] = Variable<String>(cipherAlgo.value);
    }
    if (cipherKeyRef.present) {
      map['cipher_key_ref'] = Variable<String>(cipherKeyRef.value);
    }
    if (plainBytes.present) {
      map['plain_bytes'] = Variable<int>(plainBytes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentBlobsCompanion(')
          ..write('urlKey: $urlKey, ')
          ..write('remoteUrl: $remoteUrl, ')
          ..write('localPath: $localPath, ')
          ..write('fileName: $fileName, ')
          ..write('contentType: $contentType, ')
          ..write('expectedBytes: $expectedBytes, ')
          ..write('receivedBytes: $receivedBytes, ')
          ..write('transferState: $transferState, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('downloadedAtMs: $downloadedAtMs, ')
          ..write('lastAccessMs: $lastAccessMs, ')
          ..write('exportedAtMs: $exportedAtMs, ')
          ..write('exportedPath: $exportedPath, ')
          ..write('cipherAlgo: $cipherAlgo, ')
          ..write('cipherKeyRef: $cipherKeyRef, ')
          ..write('plainBytes: $plainBytes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttachmentRefsTable extends AttachmentRefs
    with TableInfo<$AttachmentRefsTable, AttachmentRef> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttachmentRefsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _attachmentIdMeta = const VerificationMeta(
    'attachmentId',
  );
  @override
  late final GeneratedColumn<String> attachmentId = GeneratedColumn<String>(
    'attachment_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlKeyMeta = const VerificationMeta('urlKey');
  @override
  late final GeneratedColumn<String> urlKey = GeneratedColumn<String>(
    'url_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
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
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    attachmentId,
    urlKey,
    messageId,
    conversationId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attachment_refs';
  @override
  VerificationContext validateIntegrity(
    Insertable<AttachmentRef> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('attachment_id')) {
      context.handle(
        _attachmentIdMeta,
        attachmentId.isAcceptableOrUnknown(
          data['attachment_id']!,
          _attachmentIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_attachmentIdMeta);
    }
    if (data.containsKey('url_key')) {
      context.handle(
        _urlKeyMeta,
        urlKey.isAcceptableOrUnknown(data['url_key']!, _urlKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_urlKeyMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {attachmentId};
  @override
  AttachmentRef map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttachmentRef(
      attachmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachment_id'],
      )!,
      urlKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url_key'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
    );
  }

  @override
  $AttachmentRefsTable createAlias(String alias) {
    return $AttachmentRefsTable(attachedDatabase, alias);
  }
}

class AttachmentRef extends DataClass implements Insertable<AttachmentRef> {
  final String attachmentId;
  final String urlKey;
  final String messageId;
  final String conversationId;
  const AttachmentRef({
    required this.attachmentId,
    required this.urlKey,
    required this.messageId,
    required this.conversationId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['attachment_id'] = Variable<String>(attachmentId);
    map['url_key'] = Variable<String>(urlKey);
    map['message_id'] = Variable<String>(messageId);
    map['conversation_id'] = Variable<String>(conversationId);
    return map;
  }

  AttachmentRefsCompanion toCompanion(bool nullToAbsent) {
    return AttachmentRefsCompanion(
      attachmentId: Value(attachmentId),
      urlKey: Value(urlKey),
      messageId: Value(messageId),
      conversationId: Value(conversationId),
    );
  }

  factory AttachmentRef.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttachmentRef(
      attachmentId: serializer.fromJson<String>(json['attachmentId']),
      urlKey: serializer.fromJson<String>(json['urlKey']),
      messageId: serializer.fromJson<String>(json['messageId']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'attachmentId': serializer.toJson<String>(attachmentId),
      'urlKey': serializer.toJson<String>(urlKey),
      'messageId': serializer.toJson<String>(messageId),
      'conversationId': serializer.toJson<String>(conversationId),
    };
  }

  AttachmentRef copyWith({
    String? attachmentId,
    String? urlKey,
    String? messageId,
    String? conversationId,
  }) => AttachmentRef(
    attachmentId: attachmentId ?? this.attachmentId,
    urlKey: urlKey ?? this.urlKey,
    messageId: messageId ?? this.messageId,
    conversationId: conversationId ?? this.conversationId,
  );
  AttachmentRef copyWithCompanion(AttachmentRefsCompanion data) {
    return AttachmentRef(
      attachmentId: data.attachmentId.present
          ? data.attachmentId.value
          : this.attachmentId,
      urlKey: data.urlKey.present ? data.urlKey.value : this.urlKey,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentRef(')
          ..write('attachmentId: $attachmentId, ')
          ..write('urlKey: $urlKey, ')
          ..write('messageId: $messageId, ')
          ..write('conversationId: $conversationId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(attachmentId, urlKey, messageId, conversationId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttachmentRef &&
          other.attachmentId == this.attachmentId &&
          other.urlKey == this.urlKey &&
          other.messageId == this.messageId &&
          other.conversationId == this.conversationId);
}

class AttachmentRefsCompanion extends UpdateCompanion<AttachmentRef> {
  final Value<String> attachmentId;
  final Value<String> urlKey;
  final Value<String> messageId;
  final Value<String> conversationId;
  final Value<int> rowid;
  const AttachmentRefsCompanion({
    this.attachmentId = const Value.absent(),
    this.urlKey = const Value.absent(),
    this.messageId = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttachmentRefsCompanion.insert({
    required String attachmentId,
    required String urlKey,
    required String messageId,
    this.conversationId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : attachmentId = Value(attachmentId),
       urlKey = Value(urlKey),
       messageId = Value(messageId);
  static Insertable<AttachmentRef> custom({
    Expression<String>? attachmentId,
    Expression<String>? urlKey,
    Expression<String>? messageId,
    Expression<String>? conversationId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (attachmentId != null) 'attachment_id': attachmentId,
      if (urlKey != null) 'url_key': urlKey,
      if (messageId != null) 'message_id': messageId,
      if (conversationId != null) 'conversation_id': conversationId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttachmentRefsCompanion copyWith({
    Value<String>? attachmentId,
    Value<String>? urlKey,
    Value<String>? messageId,
    Value<String>? conversationId,
    Value<int>? rowid,
  }) {
    return AttachmentRefsCompanion(
      attachmentId: attachmentId ?? this.attachmentId,
      urlKey: urlKey ?? this.urlKey,
      messageId: messageId ?? this.messageId,
      conversationId: conversationId ?? this.conversationId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (attachmentId.present) {
      map['attachment_id'] = Variable<String>(attachmentId.value);
    }
    if (urlKey.present) {
      map['url_key'] = Variable<String>(urlKey.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentRefsCompanion(')
          ..write('attachmentId: $attachmentId, ')
          ..write('urlKey: $urlKey, ')
          ..write('messageId: $messageId, ')
          ..write('conversationId: $conversationId, ')
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
  late final $AttachmentBlobsTable attachmentBlobs = $AttachmentBlobsTable(
    this,
  );
  late final $AttachmentRefsTable attachmentRefs = $AttachmentRefsTable(this);
  late final Index idxCachedMessagesConvTime = Index(
    'idx_cached_messages_conv_time',
    'CREATE INDEX idx_cached_messages_conv_time ON cached_messages (conversation_id, created_at_ms)',
  );
  late final Index idxAttachmentBlobsLru = Index(
    'idx_attachment_blobs_lru',
    'CREATE INDEX idx_attachment_blobs_lru ON attachment_blobs (transfer_state, last_access_ms)',
  );
  late final Index idxAttachmentRefsUrl = Index(
    'idx_attachment_refs_url',
    'CREATE INDEX idx_attachment_refs_url ON attachment_refs (url_key)',
  );
  late final Index idxAttachmentRefsMessage = Index(
    'idx_attachment_refs_message',
    'CREATE INDEX idx_attachment_refs_message ON attachment_refs (message_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cachedSidebars,
    cachedMessages,
    pendingOutboxMessages,
    attachmentBlobs,
    attachmentRefs,
    idxCachedMessagesConvTime,
    idxAttachmentBlobsLru,
    idxAttachmentRefsUrl,
    idxAttachmentRefsMessage,
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
typedef $$AttachmentBlobsTableCreateCompanionBuilder =
    AttachmentBlobsCompanion Function({
      required String urlKey,
      required String remoteUrl,
      Value<String?> localPath,
      Value<String> fileName,
      Value<String> contentType,
      Value<int> expectedBytes,
      Value<int> receivedBytes,
      Value<int> transferState,
      Value<int> attempts,
      Value<String> lastError,
      Value<int?> downloadedAtMs,
      Value<int> lastAccessMs,
      Value<int?> exportedAtMs,
      Value<String?> exportedPath,
      Value<String> cipherAlgo,
      Value<String?> cipherKeyRef,
      Value<int?> plainBytes,
      Value<int> rowid,
    });
typedef $$AttachmentBlobsTableUpdateCompanionBuilder =
    AttachmentBlobsCompanion Function({
      Value<String> urlKey,
      Value<String> remoteUrl,
      Value<String?> localPath,
      Value<String> fileName,
      Value<String> contentType,
      Value<int> expectedBytes,
      Value<int> receivedBytes,
      Value<int> transferState,
      Value<int> attempts,
      Value<String> lastError,
      Value<int?> downloadedAtMs,
      Value<int> lastAccessMs,
      Value<int?> exportedAtMs,
      Value<String?> exportedPath,
      Value<String> cipherAlgo,
      Value<String?> cipherKeyRef,
      Value<int?> plainBytes,
      Value<int> rowid,
    });

class $$AttachmentBlobsTableFilterComposer
    extends Composer<_$ChatLocalDb, $AttachmentBlobsTable> {
  $$AttachmentBlobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get urlKey => $composableBuilder(
    column: $table.urlKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteUrl => $composableBuilder(
    column: $table.remoteUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expectedBytes => $composableBuilder(
    column: $table.expectedBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get receivedBytes => $composableBuilder(
    column: $table.receivedBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get transferState => $composableBuilder(
    column: $table.transferState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get downloadedAtMs => $composableBuilder(
    column: $table.downloadedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastAccessMs => $composableBuilder(
    column: $table.lastAccessMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get exportedAtMs => $composableBuilder(
    column: $table.exportedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exportedPath => $composableBuilder(
    column: $table.exportedPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cipherAlgo => $composableBuilder(
    column: $table.cipherAlgo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cipherKeyRef => $composableBuilder(
    column: $table.cipherKeyRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get plainBytes => $composableBuilder(
    column: $table.plainBytes,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AttachmentBlobsTableOrderingComposer
    extends Composer<_$ChatLocalDb, $AttachmentBlobsTable> {
  $$AttachmentBlobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get urlKey => $composableBuilder(
    column: $table.urlKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteUrl => $composableBuilder(
    column: $table.remoteUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expectedBytes => $composableBuilder(
    column: $table.expectedBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get receivedBytes => $composableBuilder(
    column: $table.receivedBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get transferState => $composableBuilder(
    column: $table.transferState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get downloadedAtMs => $composableBuilder(
    column: $table.downloadedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastAccessMs => $composableBuilder(
    column: $table.lastAccessMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get exportedAtMs => $composableBuilder(
    column: $table.exportedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exportedPath => $composableBuilder(
    column: $table.exportedPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cipherAlgo => $composableBuilder(
    column: $table.cipherAlgo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cipherKeyRef => $composableBuilder(
    column: $table.cipherKeyRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plainBytes => $composableBuilder(
    column: $table.plainBytes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AttachmentBlobsTableAnnotationComposer
    extends Composer<_$ChatLocalDb, $AttachmentBlobsTable> {
  $$AttachmentBlobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get urlKey =>
      $composableBuilder(column: $table.urlKey, builder: (column) => column);

  GeneratedColumn<String> get remoteUrl =>
      $composableBuilder(column: $table.remoteUrl, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get expectedBytes => $composableBuilder(
    column: $table.expectedBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get receivedBytes => $composableBuilder(
    column: $table.receivedBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get transferState => $composableBuilder(
    column: $table.transferState,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<int> get downloadedAtMs => $composableBuilder(
    column: $table.downloadedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastAccessMs => $composableBuilder(
    column: $table.lastAccessMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get exportedAtMs => $composableBuilder(
    column: $table.exportedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get exportedPath => $composableBuilder(
    column: $table.exportedPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cipherAlgo => $composableBuilder(
    column: $table.cipherAlgo,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cipherKeyRef => $composableBuilder(
    column: $table.cipherKeyRef,
    builder: (column) => column,
  );

  GeneratedColumn<int> get plainBytes => $composableBuilder(
    column: $table.plainBytes,
    builder: (column) => column,
  );
}

class $$AttachmentBlobsTableTableManager
    extends
        RootTableManager<
          _$ChatLocalDb,
          $AttachmentBlobsTable,
          AttachmentBlob,
          $$AttachmentBlobsTableFilterComposer,
          $$AttachmentBlobsTableOrderingComposer,
          $$AttachmentBlobsTableAnnotationComposer,
          $$AttachmentBlobsTableCreateCompanionBuilder,
          $$AttachmentBlobsTableUpdateCompanionBuilder,
          (
            AttachmentBlob,
            BaseReferences<
              _$ChatLocalDb,
              $AttachmentBlobsTable,
              AttachmentBlob
            >,
          ),
          AttachmentBlob,
          PrefetchHooks Function()
        > {
  $$AttachmentBlobsTableTableManager(
    _$ChatLocalDb db,
    $AttachmentBlobsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttachmentBlobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttachmentBlobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttachmentBlobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> urlKey = const Value.absent(),
                Value<String> remoteUrl = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<String> contentType = const Value.absent(),
                Value<int> expectedBytes = const Value.absent(),
                Value<int> receivedBytes = const Value.absent(),
                Value<int> transferState = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String> lastError = const Value.absent(),
                Value<int?> downloadedAtMs = const Value.absent(),
                Value<int> lastAccessMs = const Value.absent(),
                Value<int?> exportedAtMs = const Value.absent(),
                Value<String?> exportedPath = const Value.absent(),
                Value<String> cipherAlgo = const Value.absent(),
                Value<String?> cipherKeyRef = const Value.absent(),
                Value<int?> plainBytes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttachmentBlobsCompanion(
                urlKey: urlKey,
                remoteUrl: remoteUrl,
                localPath: localPath,
                fileName: fileName,
                contentType: contentType,
                expectedBytes: expectedBytes,
                receivedBytes: receivedBytes,
                transferState: transferState,
                attempts: attempts,
                lastError: lastError,
                downloadedAtMs: downloadedAtMs,
                lastAccessMs: lastAccessMs,
                exportedAtMs: exportedAtMs,
                exportedPath: exportedPath,
                cipherAlgo: cipherAlgo,
                cipherKeyRef: cipherKeyRef,
                plainBytes: plainBytes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String urlKey,
                required String remoteUrl,
                Value<String?> localPath = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<String> contentType = const Value.absent(),
                Value<int> expectedBytes = const Value.absent(),
                Value<int> receivedBytes = const Value.absent(),
                Value<int> transferState = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String> lastError = const Value.absent(),
                Value<int?> downloadedAtMs = const Value.absent(),
                Value<int> lastAccessMs = const Value.absent(),
                Value<int?> exportedAtMs = const Value.absent(),
                Value<String?> exportedPath = const Value.absent(),
                Value<String> cipherAlgo = const Value.absent(),
                Value<String?> cipherKeyRef = const Value.absent(),
                Value<int?> plainBytes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttachmentBlobsCompanion.insert(
                urlKey: urlKey,
                remoteUrl: remoteUrl,
                localPath: localPath,
                fileName: fileName,
                contentType: contentType,
                expectedBytes: expectedBytes,
                receivedBytes: receivedBytes,
                transferState: transferState,
                attempts: attempts,
                lastError: lastError,
                downloadedAtMs: downloadedAtMs,
                lastAccessMs: lastAccessMs,
                exportedAtMs: exportedAtMs,
                exportedPath: exportedPath,
                cipherAlgo: cipherAlgo,
                cipherKeyRef: cipherKeyRef,
                plainBytes: plainBytes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AttachmentBlobsTableProcessedTableManager =
    ProcessedTableManager<
      _$ChatLocalDb,
      $AttachmentBlobsTable,
      AttachmentBlob,
      $$AttachmentBlobsTableFilterComposer,
      $$AttachmentBlobsTableOrderingComposer,
      $$AttachmentBlobsTableAnnotationComposer,
      $$AttachmentBlobsTableCreateCompanionBuilder,
      $$AttachmentBlobsTableUpdateCompanionBuilder,
      (
        AttachmentBlob,
        BaseReferences<_$ChatLocalDb, $AttachmentBlobsTable, AttachmentBlob>,
      ),
      AttachmentBlob,
      PrefetchHooks Function()
    >;
typedef $$AttachmentRefsTableCreateCompanionBuilder =
    AttachmentRefsCompanion Function({
      required String attachmentId,
      required String urlKey,
      required String messageId,
      Value<String> conversationId,
      Value<int> rowid,
    });
typedef $$AttachmentRefsTableUpdateCompanionBuilder =
    AttachmentRefsCompanion Function({
      Value<String> attachmentId,
      Value<String> urlKey,
      Value<String> messageId,
      Value<String> conversationId,
      Value<int> rowid,
    });

class $$AttachmentRefsTableFilterComposer
    extends Composer<_$ChatLocalDb, $AttachmentRefsTable> {
  $$AttachmentRefsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get attachmentId => $composableBuilder(
    column: $table.attachmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get urlKey => $composableBuilder(
    column: $table.urlKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AttachmentRefsTableOrderingComposer
    extends Composer<_$ChatLocalDb, $AttachmentRefsTable> {
  $$AttachmentRefsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get attachmentId => $composableBuilder(
    column: $table.attachmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get urlKey => $composableBuilder(
    column: $table.urlKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AttachmentRefsTableAnnotationComposer
    extends Composer<_$ChatLocalDb, $AttachmentRefsTable> {
  $$AttachmentRefsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get attachmentId => $composableBuilder(
    column: $table.attachmentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get urlKey =>
      $composableBuilder(column: $table.urlKey, builder: (column) => column);

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );
}

class $$AttachmentRefsTableTableManager
    extends
        RootTableManager<
          _$ChatLocalDb,
          $AttachmentRefsTable,
          AttachmentRef,
          $$AttachmentRefsTableFilterComposer,
          $$AttachmentRefsTableOrderingComposer,
          $$AttachmentRefsTableAnnotationComposer,
          $$AttachmentRefsTableCreateCompanionBuilder,
          $$AttachmentRefsTableUpdateCompanionBuilder,
          (
            AttachmentRef,
            BaseReferences<_$ChatLocalDb, $AttachmentRefsTable, AttachmentRef>,
          ),
          AttachmentRef,
          PrefetchHooks Function()
        > {
  $$AttachmentRefsTableTableManager(
    _$ChatLocalDb db,
    $AttachmentRefsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttachmentRefsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttachmentRefsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttachmentRefsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> attachmentId = const Value.absent(),
                Value<String> urlKey = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttachmentRefsCompanion(
                attachmentId: attachmentId,
                urlKey: urlKey,
                messageId: messageId,
                conversationId: conversationId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String attachmentId,
                required String urlKey,
                required String messageId,
                Value<String> conversationId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttachmentRefsCompanion.insert(
                attachmentId: attachmentId,
                urlKey: urlKey,
                messageId: messageId,
                conversationId: conversationId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AttachmentRefsTableProcessedTableManager =
    ProcessedTableManager<
      _$ChatLocalDb,
      $AttachmentRefsTable,
      AttachmentRef,
      $$AttachmentRefsTableFilterComposer,
      $$AttachmentRefsTableOrderingComposer,
      $$AttachmentRefsTableAnnotationComposer,
      $$AttachmentRefsTableCreateCompanionBuilder,
      $$AttachmentRefsTableUpdateCompanionBuilder,
      (
        AttachmentRef,
        BaseReferences<_$ChatLocalDb, $AttachmentRefsTable, AttachmentRef>,
      ),
      AttachmentRef,
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
  $$AttachmentBlobsTableTableManager get attachmentBlobs =>
      $$AttachmentBlobsTableTableManager(_db, _db.attachmentBlobs);
  $$AttachmentRefsTableTableManager get attachmentRefs =>
      $$AttachmentRefsTableTableManager(_db, _db.attachmentRefs);
}
