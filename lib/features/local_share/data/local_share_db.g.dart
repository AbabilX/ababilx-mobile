// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_share_db.dart';

// ignore_for_file: type=lint
class $LsDevicesTable extends LsDevices
    with TableInfo<$LsDevicesTable, LsDevice> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LsDevicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceTypeMeta = const VerificationMeta(
    'deviceType',
  );
  @override
  late final GeneratedColumn<String> deviceType = GeneratedColumn<String>(
    'device_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pairTokenMeta = const VerificationMeta(
    'pairToken',
  );
  @override
  late final GeneratedColumn<String> pairToken = GeneratedColumn<String>(
    'pair_token',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _blockedMeta = const VerificationMeta(
    'blocked',
  );
  @override
  late final GeneratedColumn<bool> blocked = GeneratedColumn<bool>(
    'blocked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("blocked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastIpMeta = const VerificationMeta('lastIp');
  @override
  late final GeneratedColumn<String> lastIp = GeneratedColumn<String>(
    'last_ip',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _lastPortMeta = const VerificationMeta(
    'lastPort',
  );
  @override
  late final GeneratedColumn<int> lastPort = GeneratedColumn<int>(
    'last_port',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastSeenMsMeta = const VerificationMeta(
    'lastSeenMs',
  );
  @override
  late final GeneratedColumn<int> lastSeenMs = GeneratedColumn<int>(
    'last_seen_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    deviceId,
    name,
    deviceType,
    userId,
    pairToken,
    blocked,
    lastIp,
    lastPort,
    lastSeenMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ls_devices';
  @override
  VerificationContext validateIntegrity(
    Insertable<LsDevice> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('device_type')) {
      context.handle(
        _deviceTypeMeta,
        deviceType.isAcceptableOrUnknown(data['device_type']!, _deviceTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceTypeMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('pair_token')) {
      context.handle(
        _pairTokenMeta,
        pairToken.isAcceptableOrUnknown(data['pair_token']!, _pairTokenMeta),
      );
    }
    if (data.containsKey('blocked')) {
      context.handle(
        _blockedMeta,
        blocked.isAcceptableOrUnknown(data['blocked']!, _blockedMeta),
      );
    }
    if (data.containsKey('last_ip')) {
      context.handle(
        _lastIpMeta,
        lastIp.isAcceptableOrUnknown(data['last_ip']!, _lastIpMeta),
      );
    }
    if (data.containsKey('last_port')) {
      context.handle(
        _lastPortMeta,
        lastPort.isAcceptableOrUnknown(data['last_port']!, _lastPortMeta),
      );
    }
    if (data.containsKey('last_seen_ms')) {
      context.handle(
        _lastSeenMsMeta,
        lastSeenMs.isAcceptableOrUnknown(
          data['last_seen_ms']!,
          _lastSeenMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deviceId};
  @override
  LsDevice map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LsDevice(
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      deviceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_type'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      pairToken: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pair_token'],
      ),
      blocked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}blocked'],
      )!,
      lastIp: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_ip'],
      )!,
      lastPort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_port'],
      )!,
      lastSeenMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_seen_ms'],
      )!,
    );
  }

  @override
  $LsDevicesTable createAlias(String alias) {
    return $LsDevicesTable(attachedDatabase, alias);
  }
}

class LsDevice extends DataClass implements Insertable<LsDevice> {
  final String deviceId;
  final String name;
  final String deviceType;
  final String? userId;
  final String? pairToken;
  final bool blocked;
  final String lastIp;
  final int lastPort;
  final int lastSeenMs;
  const LsDevice({
    required this.deviceId,
    required this.name,
    required this.deviceType,
    this.userId,
    this.pairToken,
    required this.blocked,
    required this.lastIp,
    required this.lastPort,
    required this.lastSeenMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['device_id'] = Variable<String>(deviceId);
    map['name'] = Variable<String>(name);
    map['device_type'] = Variable<String>(deviceType);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    if (!nullToAbsent || pairToken != null) {
      map['pair_token'] = Variable<String>(pairToken);
    }
    map['blocked'] = Variable<bool>(blocked);
    map['last_ip'] = Variable<String>(lastIp);
    map['last_port'] = Variable<int>(lastPort);
    map['last_seen_ms'] = Variable<int>(lastSeenMs);
    return map;
  }

  LsDevicesCompanion toCompanion(bool nullToAbsent) {
    return LsDevicesCompanion(
      deviceId: Value(deviceId),
      name: Value(name),
      deviceType: Value(deviceType),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      pairToken: pairToken == null && nullToAbsent
          ? const Value.absent()
          : Value(pairToken),
      blocked: Value(blocked),
      lastIp: Value(lastIp),
      lastPort: Value(lastPort),
      lastSeenMs: Value(lastSeenMs),
    );
  }

  factory LsDevice.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LsDevice(
      deviceId: serializer.fromJson<String>(json['deviceId']),
      name: serializer.fromJson<String>(json['name']),
      deviceType: serializer.fromJson<String>(json['deviceType']),
      userId: serializer.fromJson<String?>(json['userId']),
      pairToken: serializer.fromJson<String?>(json['pairToken']),
      blocked: serializer.fromJson<bool>(json['blocked']),
      lastIp: serializer.fromJson<String>(json['lastIp']),
      lastPort: serializer.fromJson<int>(json['lastPort']),
      lastSeenMs: serializer.fromJson<int>(json['lastSeenMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deviceId': serializer.toJson<String>(deviceId),
      'name': serializer.toJson<String>(name),
      'deviceType': serializer.toJson<String>(deviceType),
      'userId': serializer.toJson<String?>(userId),
      'pairToken': serializer.toJson<String?>(pairToken),
      'blocked': serializer.toJson<bool>(blocked),
      'lastIp': serializer.toJson<String>(lastIp),
      'lastPort': serializer.toJson<int>(lastPort),
      'lastSeenMs': serializer.toJson<int>(lastSeenMs),
    };
  }

  LsDevice copyWith({
    String? deviceId,
    String? name,
    String? deviceType,
    Value<String?> userId = const Value.absent(),
    Value<String?> pairToken = const Value.absent(),
    bool? blocked,
    String? lastIp,
    int? lastPort,
    int? lastSeenMs,
  }) => LsDevice(
    deviceId: deviceId ?? this.deviceId,
    name: name ?? this.name,
    deviceType: deviceType ?? this.deviceType,
    userId: userId.present ? userId.value : this.userId,
    pairToken: pairToken.present ? pairToken.value : this.pairToken,
    blocked: blocked ?? this.blocked,
    lastIp: lastIp ?? this.lastIp,
    lastPort: lastPort ?? this.lastPort,
    lastSeenMs: lastSeenMs ?? this.lastSeenMs,
  );
  LsDevice copyWithCompanion(LsDevicesCompanion data) {
    return LsDevice(
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      name: data.name.present ? data.name.value : this.name,
      deviceType: data.deviceType.present
          ? data.deviceType.value
          : this.deviceType,
      userId: data.userId.present ? data.userId.value : this.userId,
      pairToken: data.pairToken.present ? data.pairToken.value : this.pairToken,
      blocked: data.blocked.present ? data.blocked.value : this.blocked,
      lastIp: data.lastIp.present ? data.lastIp.value : this.lastIp,
      lastPort: data.lastPort.present ? data.lastPort.value : this.lastPort,
      lastSeenMs: data.lastSeenMs.present
          ? data.lastSeenMs.value
          : this.lastSeenMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LsDevice(')
          ..write('deviceId: $deviceId, ')
          ..write('name: $name, ')
          ..write('deviceType: $deviceType, ')
          ..write('userId: $userId, ')
          ..write('pairToken: $pairToken, ')
          ..write('blocked: $blocked, ')
          ..write('lastIp: $lastIp, ')
          ..write('lastPort: $lastPort, ')
          ..write('lastSeenMs: $lastSeenMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    deviceId,
    name,
    deviceType,
    userId,
    pairToken,
    blocked,
    lastIp,
    lastPort,
    lastSeenMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LsDevice &&
          other.deviceId == this.deviceId &&
          other.name == this.name &&
          other.deviceType == this.deviceType &&
          other.userId == this.userId &&
          other.pairToken == this.pairToken &&
          other.blocked == this.blocked &&
          other.lastIp == this.lastIp &&
          other.lastPort == this.lastPort &&
          other.lastSeenMs == this.lastSeenMs);
}

class LsDevicesCompanion extends UpdateCompanion<LsDevice> {
  final Value<String> deviceId;
  final Value<String> name;
  final Value<String> deviceType;
  final Value<String?> userId;
  final Value<String?> pairToken;
  final Value<bool> blocked;
  final Value<String> lastIp;
  final Value<int> lastPort;
  final Value<int> lastSeenMs;
  final Value<int> rowid;
  const LsDevicesCompanion({
    this.deviceId = const Value.absent(),
    this.name = const Value.absent(),
    this.deviceType = const Value.absent(),
    this.userId = const Value.absent(),
    this.pairToken = const Value.absent(),
    this.blocked = const Value.absent(),
    this.lastIp = const Value.absent(),
    this.lastPort = const Value.absent(),
    this.lastSeenMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LsDevicesCompanion.insert({
    required String deviceId,
    required String name,
    required String deviceType,
    this.userId = const Value.absent(),
    this.pairToken = const Value.absent(),
    this.blocked = const Value.absent(),
    this.lastIp = const Value.absent(),
    this.lastPort = const Value.absent(),
    this.lastSeenMs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : deviceId = Value(deviceId),
       name = Value(name),
       deviceType = Value(deviceType);
  static Insertable<LsDevice> custom({
    Expression<String>? deviceId,
    Expression<String>? name,
    Expression<String>? deviceType,
    Expression<String>? userId,
    Expression<String>? pairToken,
    Expression<bool>? blocked,
    Expression<String>? lastIp,
    Expression<int>? lastPort,
    Expression<int>? lastSeenMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (deviceId != null) 'device_id': deviceId,
      if (name != null) 'name': name,
      if (deviceType != null) 'device_type': deviceType,
      if (userId != null) 'user_id': userId,
      if (pairToken != null) 'pair_token': pairToken,
      if (blocked != null) 'blocked': blocked,
      if (lastIp != null) 'last_ip': lastIp,
      if (lastPort != null) 'last_port': lastPort,
      if (lastSeenMs != null) 'last_seen_ms': lastSeenMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LsDevicesCompanion copyWith({
    Value<String>? deviceId,
    Value<String>? name,
    Value<String>? deviceType,
    Value<String?>? userId,
    Value<String?>? pairToken,
    Value<bool>? blocked,
    Value<String>? lastIp,
    Value<int>? lastPort,
    Value<int>? lastSeenMs,
    Value<int>? rowid,
  }) {
    return LsDevicesCompanion(
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
      deviceType: deviceType ?? this.deviceType,
      userId: userId ?? this.userId,
      pairToken: pairToken ?? this.pairToken,
      blocked: blocked ?? this.blocked,
      lastIp: lastIp ?? this.lastIp,
      lastPort: lastPort ?? this.lastPort,
      lastSeenMs: lastSeenMs ?? this.lastSeenMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (deviceType.present) {
      map['device_type'] = Variable<String>(deviceType.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (pairToken.present) {
      map['pair_token'] = Variable<String>(pairToken.value);
    }
    if (blocked.present) {
      map['blocked'] = Variable<bool>(blocked.value);
    }
    if (lastIp.present) {
      map['last_ip'] = Variable<String>(lastIp.value);
    }
    if (lastPort.present) {
      map['last_port'] = Variable<int>(lastPort.value);
    }
    if (lastSeenMs.present) {
      map['last_seen_ms'] = Variable<int>(lastSeenMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LsDevicesCompanion(')
          ..write('deviceId: $deviceId, ')
          ..write('name: $name, ')
          ..write('deviceType: $deviceType, ')
          ..write('userId: $userId, ')
          ..write('pairToken: $pairToken, ')
          ..write('blocked: $blocked, ')
          ..write('lastIp: $lastIp, ')
          ..write('lastPort: $lastPort, ')
          ..write('lastSeenMs: $lastSeenMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LsMessagesTable extends LsMessages
    with TableInfo<$LsMessagesTable, LsMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LsMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fromMeMeta = const VerificationMeta('fromMe');
  @override
  late final GeneratedColumn<bool> fromMe = GeneratedColumn<bool>(
    'from_me',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("from_me" IN (0, 1))',
    ),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
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
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _folderNameMeta = const VerificationMeta(
    'folderName',
  );
  @override
  late final GeneratedColumn<String> folderName = GeneratedColumn<String>(
    'folder_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sentAtMsMeta = const VerificationMeta(
    'sentAtMs',
  );
  @override
  late final GeneratedColumn<int> sentAtMs = GeneratedColumn<int>(
    'sent_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderMsMeta = const VerificationMeta(
    'orderMs',
  );
  @override
  late final GeneratedColumn<int> orderMs = GeneratedColumn<int>(
    'order_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unreadMeta = const VerificationMeta('unread');
  @override
  late final GeneratedColumn<bool> unread = GeneratedColumn<bool>(
    'unread',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("unread" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deviceId,
    fromMe,
    kind,
    body,
    folderName,
    sentAtMs,
    orderMs,
    status,
    unread,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ls_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<LsMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('from_me')) {
      context.handle(
        _fromMeMeta,
        fromMe.isAcceptableOrUnknown(data['from_me']!, _fromMeMeta),
      );
    } else if (isInserting) {
      context.missing(_fromMeMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('folder_name')) {
      context.handle(
        _folderNameMeta,
        folderName.isAcceptableOrUnknown(data['folder_name']!, _folderNameMeta),
      );
    }
    if (data.containsKey('sent_at_ms')) {
      context.handle(
        _sentAtMsMeta,
        sentAtMs.isAcceptableOrUnknown(data['sent_at_ms']!, _sentAtMsMeta),
      );
    } else if (isInserting) {
      context.missing(_sentAtMsMeta);
    }
    if (data.containsKey('order_ms')) {
      context.handle(
        _orderMsMeta,
        orderMs.isAcceptableOrUnknown(data['order_ms']!, _orderMsMeta),
      );
    } else if (isInserting) {
      context.missing(_orderMsMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('unread')) {
      context.handle(
        _unreadMeta,
        unread.isAcceptableOrUnknown(data['unread']!, _unreadMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LsMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LsMessage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      fromMe: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}from_me'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      ),
      folderName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_name'],
      ),
      sentAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sent_at_ms'],
      )!,
      orderMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_ms'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      unread: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}unread'],
      )!,
    );
  }

  @override
  $LsMessagesTable createAlias(String alias) {
    return $LsMessagesTable(attachedDatabase, alias);
  }
}

class LsMessage extends DataClass implements Insertable<LsMessage> {
  final String id;
  final String deviceId;
  final bool fromMe;
  final String kind;
  final String? body;
  final String? folderName;
  final int sentAtMs;
  final int orderMs;
  final String status;
  final bool unread;
  const LsMessage({
    required this.id,
    required this.deviceId,
    required this.fromMe,
    required this.kind,
    this.body,
    this.folderName,
    required this.sentAtMs,
    required this.orderMs,
    required this.status,
    required this.unread,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['device_id'] = Variable<String>(deviceId);
    map['from_me'] = Variable<bool>(fromMe);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || body != null) {
      map['body'] = Variable<String>(body);
    }
    if (!nullToAbsent || folderName != null) {
      map['folder_name'] = Variable<String>(folderName);
    }
    map['sent_at_ms'] = Variable<int>(sentAtMs);
    map['order_ms'] = Variable<int>(orderMs);
    map['status'] = Variable<String>(status);
    map['unread'] = Variable<bool>(unread);
    return map;
  }

  LsMessagesCompanion toCompanion(bool nullToAbsent) {
    return LsMessagesCompanion(
      id: Value(id),
      deviceId: Value(deviceId),
      fromMe: Value(fromMe),
      kind: Value(kind),
      body: body == null && nullToAbsent ? const Value.absent() : Value(body),
      folderName: folderName == null && nullToAbsent
          ? const Value.absent()
          : Value(folderName),
      sentAtMs: Value(sentAtMs),
      orderMs: Value(orderMs),
      status: Value(status),
      unread: Value(unread),
    );
  }

  factory LsMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LsMessage(
      id: serializer.fromJson<String>(json['id']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      fromMe: serializer.fromJson<bool>(json['fromMe']),
      kind: serializer.fromJson<String>(json['kind']),
      body: serializer.fromJson<String?>(json['body']),
      folderName: serializer.fromJson<String?>(json['folderName']),
      sentAtMs: serializer.fromJson<int>(json['sentAtMs']),
      orderMs: serializer.fromJson<int>(json['orderMs']),
      status: serializer.fromJson<String>(json['status']),
      unread: serializer.fromJson<bool>(json['unread']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'deviceId': serializer.toJson<String>(deviceId),
      'fromMe': serializer.toJson<bool>(fromMe),
      'kind': serializer.toJson<String>(kind),
      'body': serializer.toJson<String?>(body),
      'folderName': serializer.toJson<String?>(folderName),
      'sentAtMs': serializer.toJson<int>(sentAtMs),
      'orderMs': serializer.toJson<int>(orderMs),
      'status': serializer.toJson<String>(status),
      'unread': serializer.toJson<bool>(unread),
    };
  }

  LsMessage copyWith({
    String? id,
    String? deviceId,
    bool? fromMe,
    String? kind,
    Value<String?> body = const Value.absent(),
    Value<String?> folderName = const Value.absent(),
    int? sentAtMs,
    int? orderMs,
    String? status,
    bool? unread,
  }) => LsMessage(
    id: id ?? this.id,
    deviceId: deviceId ?? this.deviceId,
    fromMe: fromMe ?? this.fromMe,
    kind: kind ?? this.kind,
    body: body.present ? body.value : this.body,
    folderName: folderName.present ? folderName.value : this.folderName,
    sentAtMs: sentAtMs ?? this.sentAtMs,
    orderMs: orderMs ?? this.orderMs,
    status: status ?? this.status,
    unread: unread ?? this.unread,
  );
  LsMessage copyWithCompanion(LsMessagesCompanion data) {
    return LsMessage(
      id: data.id.present ? data.id.value : this.id,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      fromMe: data.fromMe.present ? data.fromMe.value : this.fromMe,
      kind: data.kind.present ? data.kind.value : this.kind,
      body: data.body.present ? data.body.value : this.body,
      folderName: data.folderName.present
          ? data.folderName.value
          : this.folderName,
      sentAtMs: data.sentAtMs.present ? data.sentAtMs.value : this.sentAtMs,
      orderMs: data.orderMs.present ? data.orderMs.value : this.orderMs,
      status: data.status.present ? data.status.value : this.status,
      unread: data.unread.present ? data.unread.value : this.unread,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LsMessage(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('fromMe: $fromMe, ')
          ..write('kind: $kind, ')
          ..write('body: $body, ')
          ..write('folderName: $folderName, ')
          ..write('sentAtMs: $sentAtMs, ')
          ..write('orderMs: $orderMs, ')
          ..write('status: $status, ')
          ..write('unread: $unread')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    deviceId,
    fromMe,
    kind,
    body,
    folderName,
    sentAtMs,
    orderMs,
    status,
    unread,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LsMessage &&
          other.id == this.id &&
          other.deviceId == this.deviceId &&
          other.fromMe == this.fromMe &&
          other.kind == this.kind &&
          other.body == this.body &&
          other.folderName == this.folderName &&
          other.sentAtMs == this.sentAtMs &&
          other.orderMs == this.orderMs &&
          other.status == this.status &&
          other.unread == this.unread);
}

class LsMessagesCompanion extends UpdateCompanion<LsMessage> {
  final Value<String> id;
  final Value<String> deviceId;
  final Value<bool> fromMe;
  final Value<String> kind;
  final Value<String?> body;
  final Value<String?> folderName;
  final Value<int> sentAtMs;
  final Value<int> orderMs;
  final Value<String> status;
  final Value<bool> unread;
  final Value<int> rowid;
  const LsMessagesCompanion({
    this.id = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.fromMe = const Value.absent(),
    this.kind = const Value.absent(),
    this.body = const Value.absent(),
    this.folderName = const Value.absent(),
    this.sentAtMs = const Value.absent(),
    this.orderMs = const Value.absent(),
    this.status = const Value.absent(),
    this.unread = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LsMessagesCompanion.insert({
    required String id,
    required String deviceId,
    required bool fromMe,
    required String kind,
    this.body = const Value.absent(),
    this.folderName = const Value.absent(),
    required int sentAtMs,
    required int orderMs,
    required String status,
    this.unread = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       deviceId = Value(deviceId),
       fromMe = Value(fromMe),
       kind = Value(kind),
       sentAtMs = Value(sentAtMs),
       orderMs = Value(orderMs),
       status = Value(status);
  static Insertable<LsMessage> custom({
    Expression<String>? id,
    Expression<String>? deviceId,
    Expression<bool>? fromMe,
    Expression<String>? kind,
    Expression<String>? body,
    Expression<String>? folderName,
    Expression<int>? sentAtMs,
    Expression<int>? orderMs,
    Expression<String>? status,
    Expression<bool>? unread,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deviceId != null) 'device_id': deviceId,
      if (fromMe != null) 'from_me': fromMe,
      if (kind != null) 'kind': kind,
      if (body != null) 'body': body,
      if (folderName != null) 'folder_name': folderName,
      if (sentAtMs != null) 'sent_at_ms': sentAtMs,
      if (orderMs != null) 'order_ms': orderMs,
      if (status != null) 'status': status,
      if (unread != null) 'unread': unread,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LsMessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? deviceId,
    Value<bool>? fromMe,
    Value<String>? kind,
    Value<String?>? body,
    Value<String?>? folderName,
    Value<int>? sentAtMs,
    Value<int>? orderMs,
    Value<String>? status,
    Value<bool>? unread,
    Value<int>? rowid,
  }) {
    return LsMessagesCompanion(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      fromMe: fromMe ?? this.fromMe,
      kind: kind ?? this.kind,
      body: body ?? this.body,
      folderName: folderName ?? this.folderName,
      sentAtMs: sentAtMs ?? this.sentAtMs,
      orderMs: orderMs ?? this.orderMs,
      status: status ?? this.status,
      unread: unread ?? this.unread,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (fromMe.present) {
      map['from_me'] = Variable<bool>(fromMe.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (folderName.present) {
      map['folder_name'] = Variable<String>(folderName.value);
    }
    if (sentAtMs.present) {
      map['sent_at_ms'] = Variable<int>(sentAtMs.value);
    }
    if (orderMs.present) {
      map['order_ms'] = Variable<int>(orderMs.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (unread.present) {
      map['unread'] = Variable<bool>(unread.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LsMessagesCompanion(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('fromMe: $fromMe, ')
          ..write('kind: $kind, ')
          ..write('body: $body, ')
          ..write('folderName: $folderName, ')
          ..write('sentAtMs: $sentAtMs, ')
          ..write('orderMs: $orderMs, ')
          ..write('status: $status, ')
          ..write('unread: $unread, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LsFilesTable extends LsFiles with TableInfo<$LsFilesTable, LsFile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LsFilesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeMeta = const VerificationMeta('mime');
  @override
  late final GeneratedColumn<String> mime = GeneratedColumn<String>(
    'mime',
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
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relPathMeta = const VerificationMeta(
    'relPath',
  );
  @override
  late final GeneratedColumn<String> relPath = GeneratedColumn<String>(
    'rel_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bytesDoneMeta = const VerificationMeta(
    'bytesDone',
  );
  @override
  late final GeneratedColumn<int> bytesDone = GeneratedColumn<int>(
    'bytes_done',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownedMeta = const VerificationMeta('owned');
  @override
  late final GeneratedColumn<bool> owned = GeneratedColumn<bool>(
    'owned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("owned" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    messageId,
    id,
    position,
    name,
    size,
    mime,
    localPath,
    relPath,
    width,
    height,
    durationMs,
    bytesDone,
    status,
    owned,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ls_files';
  @override
  VerificationContext validateIntegrity(
    Insertable<LsFile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeMeta);
    }
    if (data.containsKey('mime')) {
      context.handle(
        _mimeMeta,
        mime.isAcceptableOrUnknown(data['mime']!, _mimeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    } else if (isInserting) {
      context.missing(_localPathMeta);
    }
    if (data.containsKey('rel_path')) {
      context.handle(
        _relPathMeta,
        relPath.isAcceptableOrUnknown(data['rel_path']!, _relPathMeta),
      );
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('bytes_done')) {
      context.handle(
        _bytesDoneMeta,
        bytesDone.isAcceptableOrUnknown(data['bytes_done']!, _bytesDoneMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('owned')) {
      context.handle(
        _ownedMeta,
        owned.isAcceptableOrUnknown(data['owned']!, _ownedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {messageId, id};
  @override
  LsFile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LsFile(
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      mime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      )!,
      relPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rel_path'],
      ),
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      ),
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      bytesDone: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes_done'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      owned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}owned'],
      )!,
    );
  }

  @override
  $LsFilesTable createAlias(String alias) {
    return $LsFilesTable(attachedDatabase, alias);
  }
}

class LsFile extends DataClass implements Insertable<LsFile> {
  final String messageId;
  final String id;
  final int position;
  final String name;
  final int size;
  final String mime;
  final String localPath;
  final String? relPath;
  final int? width;
  final int? height;
  final int? durationMs;
  final int bytesDone;
  final String status;

  /// False for an outgoing file still where the user keeps it: deleting the
  /// bubble must not delete their photo.
  final bool owned;
  const LsFile({
    required this.messageId,
    required this.id,
    required this.position,
    required this.name,
    required this.size,
    required this.mime,
    required this.localPath,
    this.relPath,
    this.width,
    this.height,
    this.durationMs,
    required this.bytesDone,
    required this.status,
    required this.owned,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['message_id'] = Variable<String>(messageId);
    map['id'] = Variable<String>(id);
    map['position'] = Variable<int>(position);
    map['name'] = Variable<String>(name);
    map['size'] = Variable<int>(size);
    map['mime'] = Variable<String>(mime);
    map['local_path'] = Variable<String>(localPath);
    if (!nullToAbsent || relPath != null) {
      map['rel_path'] = Variable<String>(relPath);
    }
    if (!nullToAbsent || width != null) {
      map['width'] = Variable<int>(width);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<int>(height);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    map['bytes_done'] = Variable<int>(bytesDone);
    map['status'] = Variable<String>(status);
    map['owned'] = Variable<bool>(owned);
    return map;
  }

  LsFilesCompanion toCompanion(bool nullToAbsent) {
    return LsFilesCompanion(
      messageId: Value(messageId),
      id: Value(id),
      position: Value(position),
      name: Value(name),
      size: Value(size),
      mime: Value(mime),
      localPath: Value(localPath),
      relPath: relPath == null && nullToAbsent
          ? const Value.absent()
          : Value(relPath),
      width: width == null && nullToAbsent
          ? const Value.absent()
          : Value(width),
      height: height == null && nullToAbsent
          ? const Value.absent()
          : Value(height),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      bytesDone: Value(bytesDone),
      status: Value(status),
      owned: Value(owned),
    );
  }

  factory LsFile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LsFile(
      messageId: serializer.fromJson<String>(json['messageId']),
      id: serializer.fromJson<String>(json['id']),
      position: serializer.fromJson<int>(json['position']),
      name: serializer.fromJson<String>(json['name']),
      size: serializer.fromJson<int>(json['size']),
      mime: serializer.fromJson<String>(json['mime']),
      localPath: serializer.fromJson<String>(json['localPath']),
      relPath: serializer.fromJson<String?>(json['relPath']),
      width: serializer.fromJson<int?>(json['width']),
      height: serializer.fromJson<int?>(json['height']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      bytesDone: serializer.fromJson<int>(json['bytesDone']),
      status: serializer.fromJson<String>(json['status']),
      owned: serializer.fromJson<bool>(json['owned']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'messageId': serializer.toJson<String>(messageId),
      'id': serializer.toJson<String>(id),
      'position': serializer.toJson<int>(position),
      'name': serializer.toJson<String>(name),
      'size': serializer.toJson<int>(size),
      'mime': serializer.toJson<String>(mime),
      'localPath': serializer.toJson<String>(localPath),
      'relPath': serializer.toJson<String?>(relPath),
      'width': serializer.toJson<int?>(width),
      'height': serializer.toJson<int?>(height),
      'durationMs': serializer.toJson<int?>(durationMs),
      'bytesDone': serializer.toJson<int>(bytesDone),
      'status': serializer.toJson<String>(status),
      'owned': serializer.toJson<bool>(owned),
    };
  }

  LsFile copyWith({
    String? messageId,
    String? id,
    int? position,
    String? name,
    int? size,
    String? mime,
    String? localPath,
    Value<String?> relPath = const Value.absent(),
    Value<int?> width = const Value.absent(),
    Value<int?> height = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    int? bytesDone,
    String? status,
    bool? owned,
  }) => LsFile(
    messageId: messageId ?? this.messageId,
    id: id ?? this.id,
    position: position ?? this.position,
    name: name ?? this.name,
    size: size ?? this.size,
    mime: mime ?? this.mime,
    localPath: localPath ?? this.localPath,
    relPath: relPath.present ? relPath.value : this.relPath,
    width: width.present ? width.value : this.width,
    height: height.present ? height.value : this.height,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    bytesDone: bytesDone ?? this.bytesDone,
    status: status ?? this.status,
    owned: owned ?? this.owned,
  );
  LsFile copyWithCompanion(LsFilesCompanion data) {
    return LsFile(
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      id: data.id.present ? data.id.value : this.id,
      position: data.position.present ? data.position.value : this.position,
      name: data.name.present ? data.name.value : this.name,
      size: data.size.present ? data.size.value : this.size,
      mime: data.mime.present ? data.mime.value : this.mime,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      relPath: data.relPath.present ? data.relPath.value : this.relPath,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      bytesDone: data.bytesDone.present ? data.bytesDone.value : this.bytesDone,
      status: data.status.present ? data.status.value : this.status,
      owned: data.owned.present ? data.owned.value : this.owned,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LsFile(')
          ..write('messageId: $messageId, ')
          ..write('id: $id, ')
          ..write('position: $position, ')
          ..write('name: $name, ')
          ..write('size: $size, ')
          ..write('mime: $mime, ')
          ..write('localPath: $localPath, ')
          ..write('relPath: $relPath, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('durationMs: $durationMs, ')
          ..write('bytesDone: $bytesDone, ')
          ..write('status: $status, ')
          ..write('owned: $owned')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    messageId,
    id,
    position,
    name,
    size,
    mime,
    localPath,
    relPath,
    width,
    height,
    durationMs,
    bytesDone,
    status,
    owned,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LsFile &&
          other.messageId == this.messageId &&
          other.id == this.id &&
          other.position == this.position &&
          other.name == this.name &&
          other.size == this.size &&
          other.mime == this.mime &&
          other.localPath == this.localPath &&
          other.relPath == this.relPath &&
          other.width == this.width &&
          other.height == this.height &&
          other.durationMs == this.durationMs &&
          other.bytesDone == this.bytesDone &&
          other.status == this.status &&
          other.owned == this.owned);
}

class LsFilesCompanion extends UpdateCompanion<LsFile> {
  final Value<String> messageId;
  final Value<String> id;
  final Value<int> position;
  final Value<String> name;
  final Value<int> size;
  final Value<String> mime;
  final Value<String> localPath;
  final Value<String?> relPath;
  final Value<int?> width;
  final Value<int?> height;
  final Value<int?> durationMs;
  final Value<int> bytesDone;
  final Value<String> status;
  final Value<bool> owned;
  final Value<int> rowid;
  const LsFilesCompanion({
    this.messageId = const Value.absent(),
    this.id = const Value.absent(),
    this.position = const Value.absent(),
    this.name = const Value.absent(),
    this.size = const Value.absent(),
    this.mime = const Value.absent(),
    this.localPath = const Value.absent(),
    this.relPath = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.bytesDone = const Value.absent(),
    this.status = const Value.absent(),
    this.owned = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LsFilesCompanion.insert({
    required String messageId,
    required String id,
    required int position,
    required String name,
    required int size,
    required String mime,
    required String localPath,
    this.relPath = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.bytesDone = const Value.absent(),
    required String status,
    this.owned = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : messageId = Value(messageId),
       id = Value(id),
       position = Value(position),
       name = Value(name),
       size = Value(size),
       mime = Value(mime),
       localPath = Value(localPath),
       status = Value(status);
  static Insertable<LsFile> custom({
    Expression<String>? messageId,
    Expression<String>? id,
    Expression<int>? position,
    Expression<String>? name,
    Expression<int>? size,
    Expression<String>? mime,
    Expression<String>? localPath,
    Expression<String>? relPath,
    Expression<int>? width,
    Expression<int>? height,
    Expression<int>? durationMs,
    Expression<int>? bytesDone,
    Expression<String>? status,
    Expression<bool>? owned,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (messageId != null) 'message_id': messageId,
      if (id != null) 'id': id,
      if (position != null) 'position': position,
      if (name != null) 'name': name,
      if (size != null) 'size': size,
      if (mime != null) 'mime': mime,
      if (localPath != null) 'local_path': localPath,
      if (relPath != null) 'rel_path': relPath,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (durationMs != null) 'duration_ms': durationMs,
      if (bytesDone != null) 'bytes_done': bytesDone,
      if (status != null) 'status': status,
      if (owned != null) 'owned': owned,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LsFilesCompanion copyWith({
    Value<String>? messageId,
    Value<String>? id,
    Value<int>? position,
    Value<String>? name,
    Value<int>? size,
    Value<String>? mime,
    Value<String>? localPath,
    Value<String?>? relPath,
    Value<int?>? width,
    Value<int?>? height,
    Value<int?>? durationMs,
    Value<int>? bytesDone,
    Value<String>? status,
    Value<bool>? owned,
    Value<int>? rowid,
  }) {
    return LsFilesCompanion(
      messageId: messageId ?? this.messageId,
      id: id ?? this.id,
      position: position ?? this.position,
      name: name ?? this.name,
      size: size ?? this.size,
      mime: mime ?? this.mime,
      localPath: localPath ?? this.localPath,
      relPath: relPath ?? this.relPath,
      width: width ?? this.width,
      height: height ?? this.height,
      durationMs: durationMs ?? this.durationMs,
      bytesDone: bytesDone ?? this.bytesDone,
      status: status ?? this.status,
      owned: owned ?? this.owned,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (mime.present) {
      map['mime'] = Variable<String>(mime.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (relPath.present) {
      map['rel_path'] = Variable<String>(relPath.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (bytesDone.present) {
      map['bytes_done'] = Variable<int>(bytesDone.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (owned.present) {
      map['owned'] = Variable<bool>(owned.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LsFilesCompanion(')
          ..write('messageId: $messageId, ')
          ..write('id: $id, ')
          ..write('position: $position, ')
          ..write('name: $name, ')
          ..write('size: $size, ')
          ..write('mime: $mime, ')
          ..write('localPath: $localPath, ')
          ..write('relPath: $relPath, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('durationMs: $durationMs, ')
          ..write('bytesDone: $bytesDone, ')
          ..write('status: $status, ')
          ..write('owned: $owned, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LsPendingDeletesTable extends LsPendingDeletes
    with TableInfo<$LsPendingDeletesTable, LsPendingDelete> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LsPendingDeletesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetIdMeta = const VerificationMeta(
    'targetId',
  );
  @override
  late final GeneratedColumn<String> targetId = GeneratedColumn<String>(
    'target_id',
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
  @override
  List<GeneratedColumn> get $columns => [id, deviceId, targetId, createdAtMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ls_pending_deletes';
  @override
  VerificationContext validateIntegrity(
    Insertable<LsPendingDelete> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('target_id')) {
      context.handle(
        _targetIdMeta,
        targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_targetIdMeta);
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LsPendingDelete map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LsPendingDelete(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      targetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_id'],
      )!,
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
    );
  }

  @override
  $LsPendingDeletesTable createAlias(String alias) {
    return $LsPendingDeletesTable(attachedDatabase, alias);
  }
}

class LsPendingDelete extends DataClass implements Insertable<LsPendingDelete> {
  final String id;
  final String deviceId;
  final String targetId;
  final int createdAtMs;
  const LsPendingDelete({
    required this.id,
    required this.deviceId,
    required this.targetId,
    required this.createdAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['device_id'] = Variable<String>(deviceId);
    map['target_id'] = Variable<String>(targetId);
    map['created_at_ms'] = Variable<int>(createdAtMs);
    return map;
  }

  LsPendingDeletesCompanion toCompanion(bool nullToAbsent) {
    return LsPendingDeletesCompanion(
      id: Value(id),
      deviceId: Value(deviceId),
      targetId: Value(targetId),
      createdAtMs: Value(createdAtMs),
    );
  }

  factory LsPendingDelete.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LsPendingDelete(
      id: serializer.fromJson<String>(json['id']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      targetId: serializer.fromJson<String>(json['targetId']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'deviceId': serializer.toJson<String>(deviceId),
      'targetId': serializer.toJson<String>(targetId),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
    };
  }

  LsPendingDelete copyWith({
    String? id,
    String? deviceId,
    String? targetId,
    int? createdAtMs,
  }) => LsPendingDelete(
    id: id ?? this.id,
    deviceId: deviceId ?? this.deviceId,
    targetId: targetId ?? this.targetId,
    createdAtMs: createdAtMs ?? this.createdAtMs,
  );
  LsPendingDelete copyWithCompanion(LsPendingDeletesCompanion data) {
    return LsPendingDelete(
      id: data.id.present ? data.id.value : this.id,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LsPendingDelete(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('targetId: $targetId, ')
          ..write('createdAtMs: $createdAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, deviceId, targetId, createdAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LsPendingDelete &&
          other.id == this.id &&
          other.deviceId == this.deviceId &&
          other.targetId == this.targetId &&
          other.createdAtMs == this.createdAtMs);
}

class LsPendingDeletesCompanion extends UpdateCompanion<LsPendingDelete> {
  final Value<String> id;
  final Value<String> deviceId;
  final Value<String> targetId;
  final Value<int> createdAtMs;
  final Value<int> rowid;
  const LsPendingDeletesCompanion({
    this.id = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.targetId = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LsPendingDeletesCompanion.insert({
    required String id,
    required String deviceId,
    required String targetId,
    required int createdAtMs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       deviceId = Value(deviceId),
       targetId = Value(targetId),
       createdAtMs = Value(createdAtMs);
  static Insertable<LsPendingDelete> custom({
    Expression<String>? id,
    Expression<String>? deviceId,
    Expression<String>? targetId,
    Expression<int>? createdAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deviceId != null) 'device_id': deviceId,
      if (targetId != null) 'target_id': targetId,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LsPendingDeletesCompanion copyWith({
    Value<String>? id,
    Value<String>? deviceId,
    Value<String>? targetId,
    Value<int>? createdAtMs,
    Value<int>? rowid,
  }) {
    return LsPendingDeletesCompanion(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      targetId: targetId ?? this.targetId,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (targetId.present) {
      map['target_id'] = Variable<String>(targetId.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LsPendingDeletesCompanion(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('targetId: $targetId, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalShareDb extends GeneratedDatabase {
  _$LocalShareDb(QueryExecutor e) : super(e);
  $LocalShareDbManager get managers => $LocalShareDbManager(this);
  late final $LsDevicesTable lsDevices = $LsDevicesTable(this);
  late final $LsMessagesTable lsMessages = $LsMessagesTable(this);
  late final $LsFilesTable lsFiles = $LsFilesTable(this);
  late final $LsPendingDeletesTable lsPendingDeletes = $LsPendingDeletesTable(
    this,
  );
  late final Index idxLsMessagesThread = Index(
    'idx_ls_messages_thread',
    'CREATE INDEX idx_ls_messages_thread ON ls_messages (device_id, order_ms)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    lsDevices,
    lsMessages,
    lsFiles,
    lsPendingDeletes,
    idxLsMessagesThread,
  ];
}

typedef $$LsDevicesTableCreateCompanionBuilder =
    LsDevicesCompanion Function({
      required String deviceId,
      required String name,
      required String deviceType,
      Value<String?> userId,
      Value<String?> pairToken,
      Value<bool> blocked,
      Value<String> lastIp,
      Value<int> lastPort,
      Value<int> lastSeenMs,
      Value<int> rowid,
    });
typedef $$LsDevicesTableUpdateCompanionBuilder =
    LsDevicesCompanion Function({
      Value<String> deviceId,
      Value<String> name,
      Value<String> deviceType,
      Value<String?> userId,
      Value<String?> pairToken,
      Value<bool> blocked,
      Value<String> lastIp,
      Value<int> lastPort,
      Value<int> lastSeenMs,
      Value<int> rowid,
    });

class $$LsDevicesTableFilterComposer
    extends Composer<_$LocalShareDb, $LsDevicesTable> {
  $$LsDevicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceType => $composableBuilder(
    column: $table.deviceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pairToken => $composableBuilder(
    column: $table.pairToken,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get blocked => $composableBuilder(
    column: $table.blocked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastIp => $composableBuilder(
    column: $table.lastIp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastPort => $composableBuilder(
    column: $table.lastPort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSeenMs => $composableBuilder(
    column: $table.lastSeenMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LsDevicesTableOrderingComposer
    extends Composer<_$LocalShareDb, $LsDevicesTable> {
  $$LsDevicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceType => $composableBuilder(
    column: $table.deviceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pairToken => $composableBuilder(
    column: $table.pairToken,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get blocked => $composableBuilder(
    column: $table.blocked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastIp => $composableBuilder(
    column: $table.lastIp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPort => $composableBuilder(
    column: $table.lastPort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSeenMs => $composableBuilder(
    column: $table.lastSeenMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LsDevicesTableAnnotationComposer
    extends Composer<_$LocalShareDb, $LsDevicesTable> {
  $$LsDevicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get deviceType => $composableBuilder(
    column: $table.deviceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get pairToken =>
      $composableBuilder(column: $table.pairToken, builder: (column) => column);

  GeneratedColumn<bool> get blocked =>
      $composableBuilder(column: $table.blocked, builder: (column) => column);

  GeneratedColumn<String> get lastIp =>
      $composableBuilder(column: $table.lastIp, builder: (column) => column);

  GeneratedColumn<int> get lastPort =>
      $composableBuilder(column: $table.lastPort, builder: (column) => column);

  GeneratedColumn<int> get lastSeenMs => $composableBuilder(
    column: $table.lastSeenMs,
    builder: (column) => column,
  );
}

class $$LsDevicesTableTableManager
    extends
        RootTableManager<
          _$LocalShareDb,
          $LsDevicesTable,
          LsDevice,
          $$LsDevicesTableFilterComposer,
          $$LsDevicesTableOrderingComposer,
          $$LsDevicesTableAnnotationComposer,
          $$LsDevicesTableCreateCompanionBuilder,
          $$LsDevicesTableUpdateCompanionBuilder,
          (LsDevice, BaseReferences<_$LocalShareDb, $LsDevicesTable, LsDevice>),
          LsDevice,
          PrefetchHooks Function()
        > {
  $$LsDevicesTableTableManager(_$LocalShareDb db, $LsDevicesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LsDevicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LsDevicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LsDevicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> deviceId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> deviceType = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String?> pairToken = const Value.absent(),
                Value<bool> blocked = const Value.absent(),
                Value<String> lastIp = const Value.absent(),
                Value<int> lastPort = const Value.absent(),
                Value<int> lastSeenMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LsDevicesCompanion(
                deviceId: deviceId,
                name: name,
                deviceType: deviceType,
                userId: userId,
                pairToken: pairToken,
                blocked: blocked,
                lastIp: lastIp,
                lastPort: lastPort,
                lastSeenMs: lastSeenMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String deviceId,
                required String name,
                required String deviceType,
                Value<String?> userId = const Value.absent(),
                Value<String?> pairToken = const Value.absent(),
                Value<bool> blocked = const Value.absent(),
                Value<String> lastIp = const Value.absent(),
                Value<int> lastPort = const Value.absent(),
                Value<int> lastSeenMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LsDevicesCompanion.insert(
                deviceId: deviceId,
                name: name,
                deviceType: deviceType,
                userId: userId,
                pairToken: pairToken,
                blocked: blocked,
                lastIp: lastIp,
                lastPort: lastPort,
                lastSeenMs: lastSeenMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LsDevicesTable, LsDevice>(table),
                  BaseReferences<_$LocalShareDb, $LsDevicesTable, LsDevice>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LsDevicesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalShareDb,
      $LsDevicesTable,
      LsDevice,
      $$LsDevicesTableFilterComposer,
      $$LsDevicesTableOrderingComposer,
      $$LsDevicesTableAnnotationComposer,
      $$LsDevicesTableCreateCompanionBuilder,
      $$LsDevicesTableUpdateCompanionBuilder,
      (LsDevice, BaseReferences<_$LocalShareDb, $LsDevicesTable, LsDevice>),
      LsDevice,
      PrefetchHooks Function()
    >;
typedef $$LsMessagesTableCreateCompanionBuilder =
    LsMessagesCompanion Function({
      required String id,
      required String deviceId,
      required bool fromMe,
      required String kind,
      Value<String?> body,
      Value<String?> folderName,
      required int sentAtMs,
      required int orderMs,
      required String status,
      Value<bool> unread,
      Value<int> rowid,
    });
typedef $$LsMessagesTableUpdateCompanionBuilder =
    LsMessagesCompanion Function({
      Value<String> id,
      Value<String> deviceId,
      Value<bool> fromMe,
      Value<String> kind,
      Value<String?> body,
      Value<String?> folderName,
      Value<int> sentAtMs,
      Value<int> orderMs,
      Value<String> status,
      Value<bool> unread,
      Value<int> rowid,
    });

class $$LsMessagesTableFilterComposer
    extends Composer<_$LocalShareDb, $LsMessagesTable> {
  $$LsMessagesTableFilterComposer({
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

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get fromMe => $composableBuilder(
    column: $table.fromMe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderName => $composableBuilder(
    column: $table.folderName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sentAtMs => $composableBuilder(
    column: $table.sentAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderMs => $composableBuilder(
    column: $table.orderMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get unread => $composableBuilder(
    column: $table.unread,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LsMessagesTableOrderingComposer
    extends Composer<_$LocalShareDb, $LsMessagesTable> {
  $$LsMessagesTableOrderingComposer({
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

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get fromMe => $composableBuilder(
    column: $table.fromMe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderName => $composableBuilder(
    column: $table.folderName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sentAtMs => $composableBuilder(
    column: $table.sentAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderMs => $composableBuilder(
    column: $table.orderMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get unread => $composableBuilder(
    column: $table.unread,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LsMessagesTableAnnotationComposer
    extends Composer<_$LocalShareDb, $LsMessagesTable> {
  $$LsMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<bool> get fromMe =>
      $composableBuilder(column: $table.fromMe, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get folderName => $composableBuilder(
    column: $table.folderName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sentAtMs =>
      $composableBuilder(column: $table.sentAtMs, builder: (column) => column);

  GeneratedColumn<int> get orderMs =>
      $composableBuilder(column: $table.orderMs, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get unread =>
      $composableBuilder(column: $table.unread, builder: (column) => column);
}

class $$LsMessagesTableTableManager
    extends
        RootTableManager<
          _$LocalShareDb,
          $LsMessagesTable,
          LsMessage,
          $$LsMessagesTableFilterComposer,
          $$LsMessagesTableOrderingComposer,
          $$LsMessagesTableAnnotationComposer,
          $$LsMessagesTableCreateCompanionBuilder,
          $$LsMessagesTableUpdateCompanionBuilder,
          (
            LsMessage,
            BaseReferences<_$LocalShareDb, $LsMessagesTable, LsMessage>,
          ),
          LsMessage,
          PrefetchHooks Function()
        > {
  $$LsMessagesTableTableManager(_$LocalShareDb db, $LsMessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LsMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LsMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LsMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<bool> fromMe = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<String?> folderName = const Value.absent(),
                Value<int> sentAtMs = const Value.absent(),
                Value<int> orderMs = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> unread = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LsMessagesCompanion(
                id: id,
                deviceId: deviceId,
                fromMe: fromMe,
                kind: kind,
                body: body,
                folderName: folderName,
                sentAtMs: sentAtMs,
                orderMs: orderMs,
                status: status,
                unread: unread,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String deviceId,
                required bool fromMe,
                required String kind,
                Value<String?> body = const Value.absent(),
                Value<String?> folderName = const Value.absent(),
                required int sentAtMs,
                required int orderMs,
                required String status,
                Value<bool> unread = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LsMessagesCompanion.insert(
                id: id,
                deviceId: deviceId,
                fromMe: fromMe,
                kind: kind,
                body: body,
                folderName: folderName,
                sentAtMs: sentAtMs,
                orderMs: orderMs,
                status: status,
                unread: unread,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LsMessagesTable, LsMessage>(table),
                  BaseReferences<_$LocalShareDb, $LsMessagesTable, LsMessage>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LsMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalShareDb,
      $LsMessagesTable,
      LsMessage,
      $$LsMessagesTableFilterComposer,
      $$LsMessagesTableOrderingComposer,
      $$LsMessagesTableAnnotationComposer,
      $$LsMessagesTableCreateCompanionBuilder,
      $$LsMessagesTableUpdateCompanionBuilder,
      (LsMessage, BaseReferences<_$LocalShareDb, $LsMessagesTable, LsMessage>),
      LsMessage,
      PrefetchHooks Function()
    >;
typedef $$LsFilesTableCreateCompanionBuilder =
    LsFilesCompanion Function({
      required String messageId,
      required String id,
      required int position,
      required String name,
      required int size,
      required String mime,
      required String localPath,
      Value<String?> relPath,
      Value<int?> width,
      Value<int?> height,
      Value<int?> durationMs,
      Value<int> bytesDone,
      required String status,
      Value<bool> owned,
      Value<int> rowid,
    });
typedef $$LsFilesTableUpdateCompanionBuilder =
    LsFilesCompanion Function({
      Value<String> messageId,
      Value<String> id,
      Value<int> position,
      Value<String> name,
      Value<int> size,
      Value<String> mime,
      Value<String> localPath,
      Value<String?> relPath,
      Value<int?> width,
      Value<int?> height,
      Value<int?> durationMs,
      Value<int> bytesDone,
      Value<String> status,
      Value<bool> owned,
      Value<int> rowid,
    });

class $$LsFilesTableFilterComposer
    extends Composer<_$LocalShareDb, $LsFilesTable> {
  $$LsFilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relPath => $composableBuilder(
    column: $table.relPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytesDone => $composableBuilder(
    column: $table.bytesDone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get owned => $composableBuilder(
    column: $table.owned,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LsFilesTableOrderingComposer
    extends Composer<_$LocalShareDb, $LsFilesTable> {
  $$LsFilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relPath => $composableBuilder(
    column: $table.relPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytesDone => $composableBuilder(
    column: $table.bytesDone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get owned => $composableBuilder(
    column: $table.owned,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LsFilesTableAnnotationComposer
    extends Composer<_$LocalShareDb, $LsFilesTable> {
  $$LsFilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<String> get mime =>
      $composableBuilder(column: $table.mime, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get relPath =>
      $composableBuilder(column: $table.relPath, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bytesDone =>
      $composableBuilder(column: $table.bytesDone, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get owned =>
      $composableBuilder(column: $table.owned, builder: (column) => column);
}

class $$LsFilesTableTableManager
    extends
        RootTableManager<
          _$LocalShareDb,
          $LsFilesTable,
          LsFile,
          $$LsFilesTableFilterComposer,
          $$LsFilesTableOrderingComposer,
          $$LsFilesTableAnnotationComposer,
          $$LsFilesTableCreateCompanionBuilder,
          $$LsFilesTableUpdateCompanionBuilder,
          (LsFile, BaseReferences<_$LocalShareDb, $LsFilesTable, LsFile>),
          LsFile,
          PrefetchHooks Function()
        > {
  $$LsFilesTableTableManager(_$LocalShareDb db, $LsFilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LsFilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LsFilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LsFilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> messageId = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<String> mime = const Value.absent(),
                Value<String> localPath = const Value.absent(),
                Value<String?> relPath = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<int> bytesDone = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> owned = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LsFilesCompanion(
                messageId: messageId,
                id: id,
                position: position,
                name: name,
                size: size,
                mime: mime,
                localPath: localPath,
                relPath: relPath,
                width: width,
                height: height,
                durationMs: durationMs,
                bytesDone: bytesDone,
                status: status,
                owned: owned,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String messageId,
                required String id,
                required int position,
                required String name,
                required int size,
                required String mime,
                required String localPath,
                Value<String?> relPath = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<int> bytesDone = const Value.absent(),
                required String status,
                Value<bool> owned = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LsFilesCompanion.insert(
                messageId: messageId,
                id: id,
                position: position,
                name: name,
                size: size,
                mime: mime,
                localPath: localPath,
                relPath: relPath,
                width: width,
                height: height,
                durationMs: durationMs,
                bytesDone: bytesDone,
                status: status,
                owned: owned,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LsFilesTable, LsFile>(table),
                  BaseReferences<_$LocalShareDb, $LsFilesTable, LsFile>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LsFilesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalShareDb,
      $LsFilesTable,
      LsFile,
      $$LsFilesTableFilterComposer,
      $$LsFilesTableOrderingComposer,
      $$LsFilesTableAnnotationComposer,
      $$LsFilesTableCreateCompanionBuilder,
      $$LsFilesTableUpdateCompanionBuilder,
      (LsFile, BaseReferences<_$LocalShareDb, $LsFilesTable, LsFile>),
      LsFile,
      PrefetchHooks Function()
    >;
typedef $$LsPendingDeletesTableCreateCompanionBuilder =
    LsPendingDeletesCompanion Function({
      required String id,
      required String deviceId,
      required String targetId,
      required int createdAtMs,
      Value<int> rowid,
    });
typedef $$LsPendingDeletesTableUpdateCompanionBuilder =
    LsPendingDeletesCompanion Function({
      Value<String> id,
      Value<String> deviceId,
      Value<String> targetId,
      Value<int> createdAtMs,
      Value<int> rowid,
    });

class $$LsPendingDeletesTableFilterComposer
    extends Composer<_$LocalShareDb, $LsPendingDeletesTable> {
  $$LsPendingDeletesTableFilterComposer({
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

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LsPendingDeletesTableOrderingComposer
    extends Composer<_$LocalShareDb, $LsPendingDeletesTable> {
  $$LsPendingDeletesTableOrderingComposer({
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

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LsPendingDeletesTableAnnotationComposer
    extends Composer<_$LocalShareDb, $LsPendingDeletesTable> {
  $$LsPendingDeletesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get targetId =>
      $composableBuilder(column: $table.targetId, builder: (column) => column);

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );
}

class $$LsPendingDeletesTableTableManager
    extends
        RootTableManager<
          _$LocalShareDb,
          $LsPendingDeletesTable,
          LsPendingDelete,
          $$LsPendingDeletesTableFilterComposer,
          $$LsPendingDeletesTableOrderingComposer,
          $$LsPendingDeletesTableAnnotationComposer,
          $$LsPendingDeletesTableCreateCompanionBuilder,
          $$LsPendingDeletesTableUpdateCompanionBuilder,
          (
            LsPendingDelete,
            BaseReferences<
              _$LocalShareDb,
              $LsPendingDeletesTable,
              LsPendingDelete
            >,
          ),
          LsPendingDelete,
          PrefetchHooks Function()
        > {
  $$LsPendingDeletesTableTableManager(
    _$LocalShareDb db,
    $LsPendingDeletesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LsPendingDeletesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LsPendingDeletesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LsPendingDeletesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> targetId = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LsPendingDeletesCompanion(
                id: id,
                deviceId: deviceId,
                targetId: targetId,
                createdAtMs: createdAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String deviceId,
                required String targetId,
                required int createdAtMs,
                Value<int> rowid = const Value.absent(),
              }) => LsPendingDeletesCompanion.insert(
                id: id,
                deviceId: deviceId,
                targetId: targetId,
                createdAtMs: createdAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LsPendingDeletesTable, LsPendingDelete>(table),
                  BaseReferences<
                    _$LocalShareDb,
                    $LsPendingDeletesTable,
                    LsPendingDelete
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LsPendingDeletesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalShareDb,
      $LsPendingDeletesTable,
      LsPendingDelete,
      $$LsPendingDeletesTableFilterComposer,
      $$LsPendingDeletesTableOrderingComposer,
      $$LsPendingDeletesTableAnnotationComposer,
      $$LsPendingDeletesTableCreateCompanionBuilder,
      $$LsPendingDeletesTableUpdateCompanionBuilder,
      (
        LsPendingDelete,
        BaseReferences<_$LocalShareDb, $LsPendingDeletesTable, LsPendingDelete>,
      ),
      LsPendingDelete,
      PrefetchHooks Function()
    >;

class $LocalShareDbManager {
  final _$LocalShareDb _db;
  $LocalShareDbManager(this._db);
  $$LsDevicesTableTableManager get lsDevices =>
      $$LsDevicesTableTableManager(_db, _db.lsDevices);
  $$LsMessagesTableTableManager get lsMessages =>
      $$LsMessagesTableTableManager(_db, _db.lsMessages);
  $$LsFilesTableTableManager get lsFiles =>
      $$LsFilesTableTableManager(_db, _db.lsFiles);
  $$LsPendingDeletesTableTableManager get lsPendingDeletes =>
      $$LsPendingDeletesTableTableManager(_db, _db.lsPendingDeletes);
}
