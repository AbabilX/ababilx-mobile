import 'package:ababilx/core/storage/secure_storage.dart';
import 'package:ababilx/features/messages/data/chat_repository.dart';
import 'package:ababilx/features/messages/data/local/chat_key_cache.dart';
import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/data/models/chat_message.dart';
import 'package:ababilx/features/messages/message_e2ee/message_vault.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// One-member conversation server: enough for a vault to mint and read a key.
class _Repository implements ChatRepository {
  Map<String, dynamic> vault = {'exists': false};
  Map<String, dynamic>? selfPublicKey;
  Map<String, dynamic>? envelope;
  int version = 0;

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
    ],
    'unready_member_ids': const [],
  };

  @override
  Future<Map<String, dynamic>> createE2eeConversationKey(
    String id,
    Map<String, dynamic> envelopes,
  ) async {
    version++;
    envelope = Map<String, dynamic>.from(envelopes['me'] as Map);
    return {'key_version': version, 'envelope': envelope};
  }

  @override
  Future<Map<String, dynamic>> getE2eeConversationKey(String id) async {
    if (envelope == null) return {'exists': false};
    return {
      'exists': true,
      'key': {'key_version': version, 'envelope': envelope},
      'rekey_required': false,
      'missing_member_ids': const [],
      'gaps': const [],
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Storage implements SecureStorage {
  String? identity;
  final codes = <String, String>{};
  final pending = <String, String>{};
  @override
  Future<String?> readPendingRecovery(String userId) async => pending[userId];
  @override
  Future<void> writePendingRecovery(String userId, String value) async =>
      pending[userId] = value;
  @override
  Future<void> deletePendingRecovery(String userId) async =>
      pending.remove(userId);
  @override
  Future<String?> readMessageVaultIdentity() async => identity;
  @override
  Future<void> writeMessageVaultIdentity(String value) async =>
      identity = value;
  @override
  Future<void> deleteMessageVaultIdentity() async => identity = null;
  @override
  Future<String?> readRecoveryCode(String id) async => codes[id];
  @override
  Future<void> writeRecoveryCode(String id, String code) async =>
      codes[id] = code;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MessageVault vault;
  late int version;

  setUp(() async {
    final db = ChatLocalDb.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    vault = MessageVault(_Repository(), _Storage(), ChatKeyCache(db));
    await vault.ensureIdentity();
    version = await vault.ghostKeyVersion(
      conversationId: 'dm',
      currentUserId: 'me',
    );
  });

  Future<SealedGhostSignal> seal({String session = 's1'}) =>
      vault.sealGhostSignal(
        conversationId: 'dm',
        sessionId: session,
        senderId: 'me',
        keyVersion: version,
        payload: '{"sdp":"v=0 fingerprint:sha-256 AA:BB"}',
      );

  Future<String> open(
    SealedGhostSignal signal, {
    String session = 's1',
    String sender = 'me',
  }) => vault.openGhostSignal(
    conversationId: 'dm',
    sessionId: session,
    senderId: sender,
    currentUserId: 'me',
    keyVersion: version,
    signal: signal,
  );

  test('mints the DM key once and seals under it', () async {
    expect(version, 1);
    expect(
      await vault.ghostKeyVersion(conversationId: 'dm', currentUserId: 'me'),
      1,
      reason: 'a second invite must not rotate the DM',
    );
    expect(await open(await seal()), contains('fingerprint'));
  });

  test('a signal does not open in another session', () async {
    final signal = await seal(session: 's1');
    expect(() => open(signal, session: 's2'), throwsA(anything));
  });

  test('a signal does not open as if another person sent it', () async {
    final signal = await seal();
    expect(() => open(signal, sender: 'mallory'), throwsA(anything));
  });

  test('a relay that flips one byte gets nothing through', () async {
    final signal = await seal();
    final chars = signal.sealed.split('');
    chars[4] = chars[4] == 'A' ? 'B' : 'A';
    final tampered = SealedGhostSignal(
      sealed: chars.join(),
      nonce: signal.nonce,
    );
    expect(() => open(tampered), throwsA(anything));
  });

  test('a sealed signal can never be replayed as a chat message', () async {
    final signal = await seal();
    final asMessage = await vault.decryptMessage(
      ChatMessage(
        id: 'm',
        conversationId: 'dm',
        userId: 'me',
        body: '',
        createdAt: '2026-09-17T00:00:00Z',
        encryptedBody: signal.sealed,
        encryptionNonce: signal.nonce,
        encryptionVersion: 1,
        encryptionKeyVersion: version,
      ),
      'me',
    );
    expect(asMessage.body, 'Unable to decrypt this message');
  });
}
