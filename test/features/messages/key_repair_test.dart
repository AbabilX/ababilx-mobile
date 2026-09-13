import 'package:ababilx/core/storage/secure_storage.dart';
import 'package:ababilx/features/messages/data/chat_repository.dart';
import 'package:ababilx/features/messages/data/models/chat_message.dart';
import 'package:ababilx/features/messages/message_e2ee/message_vault.dart';
import 'package:flutter_test/flutter_test.dart';

/// A server for one account, 'me', whose roster is just itself.
class _Server implements ChatRepository {
  Map<String, dynamic> vault = {'exists': false};
  Map<String, dynamic>? publicKey;
  final envelopes = <int, Map<String, dynamic>>{};
  final reported = <int>[];
  final backfilled = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> gaps = const [];
  int latestKey = 0;
  bool refuseRemoval = false;

  // What GET .../e2ee-key answers: the newest envelope THIS account holds.
  int get _newest => envelopes.keys.fold(0, (a, b) => a > b ? a : b);

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
      'vault': {'public_key': public, 'recovery': recovery},
    };
  }

  @override
  Future<Map<String, dynamic>> getE2eeConversationMembers(String id) async => {
    'members': [
      {'user_id': 'me', 'public_key': publicKey},
    ],
    'unready_member_ids': const [],
  };
  @override
  Future<Map<String, dynamic>> createE2eeConversationKey(
    String id,
    Map<String, dynamic> sealed,
  ) async {
    // Rotates only when the newest version has no envelope for this account,
    // the server's own staleness rule for a one-member roster.
    if (latestKey == 0 || !envelopes.containsKey(latestKey)) {
      latestKey++;
      envelopes[latestKey] = Map<String, dynamic>.from(sealed['me'] as Map);
    }
    return {'key_version': _newest, 'envelope': envelopes[_newest]};
  }

  @override
  Future<Map<String, dynamic>> getE2eeConversationKey(String id) async {
    if (envelopes.isEmpty) return {'exists': false};
    return {
      'exists': true,
      'key': {'key_version': _newest, 'envelope': envelopes[_newest]},
      'rekey_required': false,
      'gaps': gaps,
    };
  }

  @override
  Future<Map<String, dynamic>> reportUnreadableE2eeEnvelope(
    String id,
    int version,
    Map<String, dynamic> public,
  ) async {
    reported.add(version);
    final removed = !refuseRemoval && public['x'] == publicKey?['x'];
    if (removed) envelopes.remove(version);
    return {'removed': removed};
  }

  @override
  Future<Map<String, dynamic>> getE2eeFillableGaps() async => {
    'conversation_ids': gaps.isEmpty ? const [] : ['group'],
  };
  @override
  Future<Map<String, dynamic>> getE2eePublicKey(String userId) async => {
    'public_key': publicKey,
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

class _Storage implements SecureStorage {
  String? identity;
  final values = <String, String>{};
  @override
  Future<String?> readMessageVaultIdentity() async => identity;
  @override
  Future<void> writeMessageVaultIdentity(String value) async =>
      identity = value;
  @override
  Future<String?> readPendingRecovery(String id) async => values['p:$id'];
  @override
  Future<void> writePendingRecovery(String id, String value) async =>
      values['p:$id'] = value;
  @override
  Future<void> deletePendingRecovery(String id) async => values.remove('p:$id');
  @override
  Future<String?> readRecoveryCode(String id) async => values[id];
  @override
  Future<void> writeRecoveryCode(String id, String code) async =>
      values[id] = code;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// An envelope for 'me' sealed to an identity this account does not hold: the
/// row a member writes after reading our public key a moment before a reset.
Future<Map<String, dynamic>> _sealedToSomebodyElse() async {
  final elsewhere = _Server();
  final vault = MessageVault(elsewhere, _Storage());
  await vault.ensureIdentity();
  await vault.encryptNew(
    conversationId: 'group',
    text: 'x',
    currentUserId: 'me',
  );
  return elsewhere.envelopes[1]!;
}

ChatMessage _message(EncryptedDmPayload payload) => ChatMessage(
  id: 'm${payload.keyVersion}',
  conversationId: 'group',
  userId: 'me',
  body: '',
  createdAt: '2026-09-13T00:00:00Z',
  encryptedBody: payload.encryptedBody,
  encryptionNonce: payload.nonce,
  encryptionVersion: 1,
  encryptionKeyVersion: payload.keyVersion,
);

Future<MessageVault> _unlocked(_Server server) async {
  final vault = MessageVault(server, _Storage());
  await vault.ensureIdentity();
  return vault;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'an envelope that does not open is reported, and the send rotates',
    () async {
      final server = _Server();
      final vault = await _unlocked(server);
      server.envelopes[1] = await _sealedToSomebodyElse();
      server.latestKey = 1;

      final sent = await vault.encryptNew(
        conversationId: 'group',
        text: 'still sends',
        currentUserId: 'me',
      );
      expect(server.reported, [1]);
      expect(sent.keyVersion, 2);
      expect(
        (await vault.decryptMessage(_message(sent), 'me')).body,
        'still sends',
      );
    },
  );

  test('an unopenable version is reported once, not per message', () async {
    final server = _Server()..refuseRemoval = true;
    final vault = await _unlocked(server);
    final ours = await vault.encryptNew(
      conversationId: 'group',
      text: 'a',
      currentUserId: 'me',
    );
    server.envelopes[2] = await _sealedToSomebodyElse();
    server.latestKey = 2;

    final broken = EncryptedDmPayload(
      encryptedBody: ours.encryptedBody,
      nonce: ours.nonce,
      keyVersion: 2,
    );
    for (var i = 0; i < 3; i++) {
      final read = await vault.decryptMessage(_message(broken), 'me');
      expect(read.body, 'Unable to decrypt this message');
    }
    expect(server.reported, [2]);
  });

  test(
    'keys other members lost are refilled without opening the chat',
    () async {
      final server = _Server();
      final vault = await _unlocked(server);
      await vault.encryptNew(
        conversationId: 'group',
        text: 'a',
        currentUserId: 'me',
      );
      server.gaps = [
        {
          'key_version': 1,
          'envelope': server.envelopes[1],
          'user_ids': ['peer'],
        },
      ];

      await vault.fillKeyGaps('me');
      await vault.fillKeyGaps('me');
      expect(server.backfilled.map((e) => [e['user_id'], e['key_version']]), [
        ['peer', 1],
      ]);
    },
  );
}
