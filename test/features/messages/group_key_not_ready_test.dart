import 'package:ababilx/core/storage/secure_storage.dart';
import 'package:ababilx/features/messages/chat-forward/forward_targets.dart';
import 'package:ababilx/features/messages/data/chat_repository.dart';
import 'package:ababilx/features/messages/data/local/chat_key_cache.dart';
import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/data/models/chat_conversation.dart';
import 'package:ababilx/features/messages/data/models/chat_conversation_json.dart';
import 'package:ababilx/features/messages/message_e2ee/dm_key_rotation.dart';
import 'package:ababilx/features/messages/message_e2ee/message_vault.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// A group converted from a workspace channel by the server's migration 0145
/// arrives with no conversation key, and with members who may never have set
/// up secure messages. The server takes plaintext in a group exactly until its
/// first key exists; these pin that the phone uses that window and only it.
class _Repository implements ChatRepository {
  Map<String, dynamic> vault = {'exists': false};
  Map<String, dynamic>? selfPublicKey;
  Map<String, dynamic>? storedEnvelope;
  int keyVersion = 0;
  bool peerReady = true;
  bool rekeyRequired = false;

  @override
  Future<Map<String, dynamic>> getE2eeVault() async => vault;

  @override
  Future<void> putE2eeRecoveryVault(
    Map<String, dynamic> public,
    Map<String, dynamic> recovery,
  ) async {
    selfPublicKey = public;
    vault = {
      'exists': true,
      'has_recovery': true,
      'vault': {'public_key': public, 'recovery': recovery},
    };
  }

  @override
  Future<Map<String, dynamic>> getE2eeConversationMembers(String id) async => {
    'members': [
      {'user_id': 'me', 'public_key': selfPublicKey},
      if (peerReady) {'user_id': 'peer', 'public_key': selfPublicKey},
    ],
    'unready_member_ids': peerReady ? const [] : const ['peer'],
  };

  @override
  Future<Map<String, dynamic>> createE2eeConversationKey(
    String id,
    Map<String, dynamic> envelopes,
  ) async {
    keyVersion++;
    storedEnvelope = Map<String, dynamic>.from(envelopes['me'] as Map);
    return {'key_version': keyVersion, 'envelope': storedEnvelope};
  }

  @override
  Future<Map<String, dynamic>> getE2eeConversationKey(String id) async {
    if (storedEnvelope == null) return {'exists': false};
    return {
      'exists': true,
      'key': {'key_version': keyVersion, 'envelope': storedEnvelope},
      'rekey_required': rekeyRequired,
      'missing_member_ids': const [],
      'gaps': const [],
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Storage implements SecureStorage {
  String? identity;
  final _recoveryCodes = <String, String>{};
  final _pendingRecovery = <String, String>{};
  @override
  Future<String?> readMessageVaultIdentity() async => identity;
  @override
  Future<void> writeMessageVaultIdentity(String value) async =>
      identity = value;
  @override
  Future<void> deleteMessageVaultIdentity() async => identity = null;
  @override
  Future<String?> readRecoveryCode(String identityId) async =>
      _recoveryCodes[identityId];
  @override
  Future<void> writeRecoveryCode(String identityId, String code) async =>
      _recoveryCodes[identityId] = code;
  @override
  Future<String?> readPendingRecovery(String userId) async =>
      _pendingRecovery[userId];
  @override
  Future<void> writePendingRecovery(String userId, String value) async =>
      _pendingRecovery[userId] = value;
  @override
  Future<void> deletePendingRecovery(String userId) async =>
      _pendingRecovery.remove(userId);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChatKeyCache cache;
  late _Repository repo;
  late _Storage storage;

  setUp(() {
    final db = ChatLocalDb.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    cache = ChatKeyCache(db);
    repo = _Repository()..peerReady = false;
    storage = _Storage();
  });

  Future<MessageVault> unlocked() async {
    final vault = MessageVault(repo, storage, cache);
    await vault.ensureIdentity();
    return vault;
  }

  test(
    'no key yet and somebody unready is "not ready", not a failure',
    () async {
      final vault = await unlocked();
      await expectLater(
        vault.encryptNew(conversationId: 'g', text: 'hi', currentUserId: 'me'),
        throwsA(isA<ChatKeyNotReady>()),
      );
      // Still a StateError, so every screen that already shows one's message
      // keeps doing so.
      await expectLater(
        vault.encryptNew(conversationId: 'g', text: 'hi', currentUserId: 'me'),
        throwsA(isA<StateError>()),
      );
      expect(repo.storedEnvelope, isNull, reason: 'nobody was locked out');
    },
  );

  // The helper does what its caller allows; which conversations may pass a
  // fallback at all is the server's call — see the group below.
  test(
    'a marked group sends as it is until everyone can be sealed to',
    () async {
      final vault = await unlocked();
      var sealed = 0;
      final sent = await sendEncryptedChat<String>(
        vault: vault,
        conversationId: 'g',
        text: 'hello',
        currentUserId: 'me',
        send: (_) async {
          sealed++;
          return 'sealed';
        },
        sendUnencrypted: () async => 'plain',
      );
      expect(sent, 'plain');
      expect(sealed, 0);

      // The first send after they set up secure messages mints the key.
      repo.peerReady = true;
      final next = await sendEncryptedChat<String>(
        vault: vault,
        conversationId: 'g',
        text: 'hello again',
        currentUserId: 'me',
        send: (_) async => 'sealed',
        sendUnencrypted: () async => 'plain',
      );
      expect(next, 'sealed');
      expect(repo.keyVersion, 1);
    },
  );

  test('a DM has no plaintext to fall back to', () async {
    final vault = await unlocked();
    await expectLater(
      sendEncryptedChat<String>(
        vault: vault,
        conversationId: 'dm',
        text: 'hi',
        currentUserId: 'me',
        send: (_) async => 'sealed',
      ),
      throwsA(isA<ChatKeyNotReady>()),
    );
  });

  test('a group that already has a key is never downgraded', () async {
    repo.peerReady = true;
    final vault = await unlocked();
    await vault.encryptNew(conversationId: 'g', text: 'x', currentUserId: 'me');

    // Somebody joins with no identity and the key is spent. The conversation
    // is encrypted now, so the failure must stay a failure.
    repo
      ..peerReady = false
      ..rekeyRequired = true;
    final relaunched = MessageVault(repo, storage, cache);
    await relaunched.restoreTrustedIdentity();
    Object? thrown;
    try {
      await sendEncryptedChat<String>(
        vault: relaunched,
        conversationId: 'g',
        text: 'y',
        currentUserId: 'me',
        send: (_) async => 'sealed',
        sendUnencrypted: () async => 'plain',
      );
    } catch (error) {
      thrown = error;
    }
    expect(thrown, isA<StateError>());
    expect(thrown, isNot(isA<ChatKeyNotReady>()));
  });

  group('the plaintext exception is the server\'s call, never the type\'s', () {
    ChatConversation groupRow({required bool marked}) =>
        ChatConversation.fromJson({
          'id': 'g',
          'scope': 'personal',
          'type': 'group',
          'name': 'G',
          'created_at': '2026-09-12T00:00:00Z',
          if (marked) 'plaintext_until_keyed': true,
        });

    test('only a marked group carries it, and the cache keeps it', () {
      expect(groupRow(marked: false).plaintextUntilKeyed, isFalse);
      final marked = groupRow(marked: true);
      expect(marked.plaintextUntilKeyed, isTrue);
      expect(
        ChatConversation.fromJson(marked.toJson()).plaintextUntilKeyed,
        isTrue,
      );
    });

    test('forwarding into a converted, unkeyed group sends it as is', () async {
      final vault = await unlocked();
      final targets = await buildForwardTargets(
        vault: vault,
        currentUserId: 'me',
        text: 'fwd',
        conversations: [groupRow(marked: true)],
      );
      expect(targets.single['message'], {'body': 'fwd'});
    });

    // A personal group created as one used to refuse this send, and still
    // must: the converted-channel exception may not leak into it.
    test('forwarding into a group created as one refuses', () async {
      final vault = await unlocked();
      await expectLater(
        buildForwardTargets(
          vault: vault,
          currentUserId: 'me',
          text: 'fwd',
          conversations: [groupRow(marked: false)],
        ),
        throwsA(isA<ChatKeyNotReady>()),
      );
    });

    // The mark is the server's word. A group this phone has known as
    // encrypted does not go back to plaintext because the list says so.
    test('a pinned group ignores the mark and refuses', () async {
      final vault = await unlocked();
      await expectLater(
        buildForwardTargets(
          vault: vault,
          currentUserId: 'me',
          text: 'fwd',
          conversations: [groupRow(marked: true)],
          pinned: {'g'},
        ),
        throwsA(isA<ChatKeyNotReady>()),
      );
    });

    // A pinned chat the list now calls a feed is still sealed to.
    test('a pinned chat relabelled as a feed is sealed, not copied', () async {
      repo.peerReady = true;
      final vault = await unlocked();
      final relabelled = ChatConversation.fromJson({
        'id': 'g',
        'scope': 'personal',
        'type': 'webhook',
        'name': 'G',
        'created_at': '2026-09-12T00:00:00Z',
      });
      expect(relabelled.isEncrypted, isFalse);
      final targets = await buildForwardTargets(
        vault: vault,
        currentUserId: 'me',
        text: 'secret',
        conversations: [relabelled],
        pinned: {'g'},
      );
      expect(targets.single.toString(), isNot(contains('secret')));
    });
  });

  test(
    'holding a conversation key reports it, so the chat is pinned',
    () async {
      repo.peerReady = true;
      final held = <String>[];
      final vault = await unlocked()
        ..onKeyHeld = (userId, conversationId) =>
            held.add('$userId:$conversationId');
      await vault.encryptNew(
        conversationId: 'g',
        text: 'x',
        currentUserId: 'me',
      );
      expect(held, ['me:g']);
    },
  );

  test('every other member a key is sealed to is reported', () async {
    repo.peerReady = true;
    final sealedTo = <String>[];
    final vault = await unlocked()
      ..onSealingTo = (self, userId, publicJwk) {
        expect(publicJwk['x'], isNotNull);
        sealedTo.add('$self>$userId');
      };
    await vault.encryptNew(conversationId: 'g', text: 'x', currentUserId: 'me');
    expect(sealedTo, containsAll(['me>me', 'me>peer']));
  });
}
