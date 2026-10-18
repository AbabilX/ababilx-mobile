import 'package:ababilx/core/storage/secure_storage.dart';
import 'package:ababilx/features/messages/data/chat_repository.dart';

/// A server and a keystore for one account, counting the key requests the
/// backup's opener makes (`backup_body_opener_test.dart`).
class BackupVaultRepository implements ChatRepository {
  Map<String, dynamic> vault = {'exists': false};
  Map<String, dynamic>? selfPublicKey;
  Map<String, dynamic>? storedEnvelope;
  int keyVersion = 0;
  int keyFetches = 0;
  int versionFetches = 0;

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
    keyVersion++;
    storedEnvelope = Map<String, dynamic>.from(envelopes['me'] as Map);
    return {'key_version': keyVersion, 'envelope': storedEnvelope};
  }

  @override
  Future<Map<String, dynamic>> getE2eeConversationKey(String id) async {
    keyFetches++;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    if (storedEnvelope == null) return {'exists': false};
    return {
      'exists': true,
      'key': {'key_version': keyVersion, 'envelope': storedEnvelope},
      'rekey_required': false,
      'missing_member_ids': const [],
      'gaps': const [],
    };
  }

  @override
  Future<Map<String, dynamic>> getE2eeConversationKeyVersions(
    String conversationId,
    List<int> versions,
  ) async {
    versionFetches++;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return {'envelopes': const []};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class BackupVaultStorage implements SecureStorage {
  String? identity;
  final pendingRecovery = <String, String>{};
  final recoveryCodes = <String, String>{};
  @override
  Future<String?> readMessageVaultIdentity() async => identity;
  @override
  Future<void> writeMessageVaultIdentity(String value) async =>
      identity = value;
  @override
  Future<void> deleteMessageVaultIdentity() async => identity = null;
  @override
  Future<String?> readPendingRecovery(String userId) async =>
      pendingRecovery[userId];
  @override
  Future<void> writePendingRecovery(String userId, String value) async =>
      pendingRecovery[userId] = value;
  @override
  Future<void> deletePendingRecovery(String userId) async =>
      pendingRecovery.remove(userId);
  @override
  Future<String?> readRecoveryCode(String identityId) async =>
      recoveryCodes[identityId];
  @override
  Future<void> writeRecoveryCode(String identityId, String code) async =>
      recoveryCodes[identityId] = code;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
