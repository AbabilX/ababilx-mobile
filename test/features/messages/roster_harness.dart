import 'package:ababilx/core/storage/secure_storage.dart';
import 'package:ababilx/features/messages/data/chat_repository.dart';
import 'package:ababilx/features/messages/data/local/chat_key_cache.dart';
import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/message_e2ee/message_vault.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// A server for one account ([self]) in one conversation: it keeps that
/// account's envelope for every key version, and says who lost which.
class RosterServer implements ChatRepository {
  RosterServer(this.self);
  final String self;
  Map<String, dynamic> vault = {'exists': false};
  Map<String, dynamic>? publicKey;

  /// Other people's identities. Anyone not listed answers with [publicKey].
  final keys = <String, Map<String, dynamic>>{};
  final envelopes = <int, Map<String, dynamic>>{};
  final sealedTo = <int, Set<String>>{};
  final backfilled = <Map<String, dynamic>>[];
  List<String> rosterIds = [];

  /// Key version -> the members the server says hold no envelope for it.
  Map<int, List<String>> gaps = {};
  int latest = 0;

  List<List<Object?>> get handed => [
    for (final e in backfilled) [e['user_id'], e['key_version']],
  ];

  @override
  Future<Map<String, dynamic>> getE2eeVault() async => vault;

  @override
  Future<void> putE2eeRecoveryVault(
    Map<String, dynamic> public,
    Map<String, dynamic> recovery,
  ) async {
    publicKey = public;
    vault = {
      'exists': true,
      'has_recovery': true,
      'vault': {'public_key': public, 'recovery': recovery},
    };
  }

  @override
  Future<Map<String, dynamic>> getE2eeConversationMembers(String id) async => {
    'members': [
      for (final member in rosterIds)
        {'user_id': member, 'public_key': keys[member] ?? publicKey},
    ],
    'unready_member_ids': const [],
  };

  @override
  Future<Map<String, dynamic>> createE2eeConversationKey(
    String id,
    Map<String, dynamic> sealed,
  ) async {
    latest++;
    envelopes[latest] = Map<String, dynamic>.from(sealed[self] as Map);
    sealedTo[latest] = sealed.keys.toSet();
    return {'key_version': latest, 'envelope': envelopes[latest]};
  }

  @override
  Future<Map<String, dynamic>> getE2eeConversationKey(String id) async => {
    'exists': latest > 0,
    if (latest > 0) 'key': {'key_version': latest, 'envelope': envelopes[latest]},
    'rekey_required': false,
    'gaps': [
      for (final gap in gaps.entries)
        {
          'key_version': gap.key,
          'envelope': envelopes[gap.key],
          'user_ids': gap.value,
        },
    ],
  };

  @override
  Future<Map<String, dynamic>> getE2eePublicKey(String userId) async => {
    'public_key': keys[userId] ?? publicKey,
  };

  @override
  Future<Map<String, dynamic>> getE2eeFillableGaps() async => {
    'conversation_ids': gaps.isEmpty ? const [] : ['chat'],
  };

  @override
  Future<Map<String, dynamic>> backfillE2eeConversationKey(
    String id,
    List<Map<String, dynamic>> items,
  ) async {
    backfilled.addAll(items);
    return {'inserted': items.length};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MemoryVaultStorage implements SecureStorage {
  final _values = <String, String>{};
  @override
  Future<String?> readMessageVaultIdentity() async => _values['identity'];
  @override
  Future<void> writeMessageVaultIdentity(String value) async =>
      _values['identity'] = value;
  @override
  Future<String?> readRecoveryCode(String id) async => _values['code:$id'];
  @override
  Future<void> writeRecoveryCode(String id, String code) async =>
      _values['code:$id'] = code;
  @override
  Future<String?> readPendingRecovery(String id) async => _values['wait:$id'];
  @override
  Future<void> writePendingRecovery(String id, String value) async =>
      _values['wait:$id'] = value;
  @override
  Future<void> deletePendingRecovery(String id) async =>
      _values.remove('wait:$id');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// One phone: a server, and the storage and key cache a restart keeps.
class RosterPhone {
  RosterPhone(String self) : server = RosterServer(self) {
    final db = ChatLocalDb.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    cache = ChatKeyCache(db);
  }

  final RosterServer server;
  final storage = MemoryVaultStorage();
  late final ChatKeyCache cache;

  /// The app's vault. Called again, it is the same account after a restart:
  /// nothing in memory, so the next send reads the key and its gaps.
  Future<MessageVault> open() async {
    final vault = MessageVault(server, storage, cache);
    await vault.ensureIdentity();
    return vault;
  }

  /// The vault a notification isolate builds by hand: no key cache.
  Future<MessageVault> openBare() async {
    final vault = MessageVault(server, storage);
    await vault.ensureIdentity();
    return vault;
  }
}

/// A public identity that is nobody's in the test: what a swapped key or a
/// person who started fresh looks like.
Future<Map<String, dynamic>> strangerIdentity() async {
  final server = RosterServer('stranger');
  await MessageVault(server, MemoryVaultStorage()).ensureIdentity();
  return server.publicKey!;
}
