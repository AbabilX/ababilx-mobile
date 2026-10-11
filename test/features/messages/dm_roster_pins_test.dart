import 'package:ababilx/core/storage/secure_storage.dart';
import 'package:ababilx/features/messages/data/chat_repository.dart';
import 'package:ababilx/features/messages/data/local/chat_key_cache.dart';
import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/data/models/chat_conversation.dart';
import 'package:ababilx/features/messages/message_e2ee/encryption_pins.dart';
import 'package:ababilx/features/messages/message_e2ee/message_vault.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A DM is between two people. These pin that an extra id in a DM's roster,
/// or in its backfill list, is sealed nothing.
class _Repository implements ChatRepository {
  _Repository(this.self);
  final String self;
  Map<String, dynamic> vault = {'exists': false};
  Map<String, dynamic>? publicKey;
  Map<String, dynamic>? envelope;
  Map<String, dynamic> sealedTo = {};
  List<Map<String, dynamic>> backfilled = [];
  List<String> rosterIds = [];
  List<String> unreadyIds = [];
  List<String> gapIds = [];

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
        {'user_id': member, 'public_key': publicKey},
    ],
    'unready_member_ids': unreadyIds,
  };

  @override
  Future<Map<String, dynamic>> createE2eeConversationKey(
    String id,
    Map<String, dynamic> envelopes,
  ) async {
    sealedTo = envelopes;
    envelope = Map<String, dynamic>.from(envelopes[self] as Map);
    return {'key_version': 1, 'envelope': envelope};
  }

  @override
  Future<Map<String, dynamic>> getE2eeConversationKey(String id) async => {
    'exists': envelope != null,
    if (envelope != null) 'key': {'key_version': 1, 'envelope': envelope},
    'rekey_required': false,
    'missing_member_ids': const [],
    'gaps': [
      if (gapIds.isNotEmpty)
        {'key_version': 1, 'envelope': envelope, 'user_ids': gapIds},
    ],
  };

  @override
  Future<Map<String, dynamic>> getE2eePublicKey(String userId) async => {
    'public_key': publicKey,
  };

  @override
  Future<Map<String, dynamic>> backfillE2eeConversationKey(
    String id,
    List<Map<String, dynamic>> envelopes,
  ) async {
    backfilled = envelopes;
    return {'inserted': envelopes.length};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Storage implements SecureStorage {
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

ChatConversation _dm(String id, {String? peer, bool self = false}) =>
    ChatConversation.fromJson({
      'id': id,
      'scope': 'personal',
      'type': 'dm',
      'peer_user_id': ?peer,
      'is_self': self,
      'created_at': '2026-10-11T00:00:00Z',
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pins = DmRosterPins();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  late ChatKeyCache cache;
  late _Storage storage;

  // Called again in one test, it is the same account on a restarted app.
  Future<MessageVault> open(_Repository repo) async {
    final vault = MessageVault(repo, storage, cache);
    await vault.ensureIdentity();
    return vault;
  }

  Future<(MessageVault, _Repository)> unlocked(String self) async {
    final db = ChatLocalDb.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    cache = ChatKeyCache(db);
    storage = _Storage();
    final repo = _Repository(self);
    return (await open(repo), repo);
  }

  test('a DM is pinned to its first peer and never to another', () async {
    expect(await pins.roster('a', 'dm'), isNull);
    await pins.observe('a', [_dm('dm', peer: 'bob')]);
    expect(await pins.roster('a', 'dm'), {'a', 'bob'});
    // The list now names somebody else as this chat's peer.
    await pins.observe('a', [_dm('dm', peer: 'mallory')]);
    expect(await pins.roster('a', 'dm'), {'a', 'bob'});
    await pins.observe('a', [_dm('note', self: true)]);
    expect(await pins.roster('a', 'note'), {'a'});
    expect(await pins.roster('a', 'some-group'), isNull);
    final stored = await SharedPreferences.getInstance();
    expect(stored.getStringList('chat_dm_peers_v1:a'), contains('dm bob'));
  });

  test('a DM key is sealed to its two people, not to a third row', () async {
    final (vault, repo) = await unlocked('b');
    await pins.observe('b', [_dm('dm', peer: 'bob')]);
    repo.rosterIds = ['b', 'bob', 'ghost'];
    await vault.encryptNew(conversationId: 'dm', text: 'x', currentUserId: 'b');
    expect(repo.sealedTo.keys, unorderedEquals(['b', 'bob']));
  });

  test('an unready stranger in a DM roster does not block the send', () async {
    final (vault, repo) = await unlocked('c');
    await pins.observe('c', [_dm('dm', peer: 'bob')]);
    repo
      ..rosterIds = ['c', 'bob']
      ..unreadyIds = ['ghost'];
    await vault.encryptNew(conversationId: 'dm', text: 'x', currentUserId: 'c');
    expect(repo.sealedTo.keys, unorderedEquals(['c', 'bob']));
  });

  test('an old DM key is handed back only to the peer', () async {
    final (vault, repo) = await unlocked('d');
    await pins.observe('d', [_dm('dm', peer: 'bob')]);
    repo.rosterIds = ['d', 'bob'];
    await vault.encryptNew(conversationId: 'dm', text: 'x', currentUserId: 'd');
    repo.gapIds = ['bob', 'ghost'];
    // A restarted app has no key in memory, so it reads the key and its gaps.
    final again = await open(repo);
    await again.encryptNew(conversationId: 'dm', text: 'y', currentUserId: 'd');
    expect(repo.backfilled.map((e) => e['user_id']), ['bob']);
  });

  test('a group is sealed to the roster the server lists', () async {
    final (vault, repo) = await unlocked('e');
    repo.rosterIds = ['e', 'bob', 'carol'];
    await vault.encryptNew(conversationId: 'g', text: 'x', currentUserId: 'e');
    expect(repo.sealedTo.keys, unorderedEquals(['e', 'bob', 'carol']));
  });
}
