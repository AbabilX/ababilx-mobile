import 'package:ababilx/core/storage/secure_storage.dart';
import 'package:ababilx/features/messages/data/chat_repository.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/message_e2ee/message_vault.dart';

/// A server that holds one key per conversation, each sealed to the one
/// identity in play — enough for a vault to mint, cache and reopen keys for
/// several conversations at once.
class SealFakeRepository implements ChatRepository {
  Map<String, dynamic> vault = {'exists': false};
  Map<String, dynamic>? selfPublicKey;
  final envelopes = <String, Map<String, dynamic>>{};
  final versions = <String, int>{};

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
      {'user_id': 'peer', 'public_key': selfPublicKey},
    ],
    'unready_member_ids': const [],
  };

  @override
  Future<Map<String, dynamic>> createE2eeConversationKey(
    String id,
    Map<String, dynamic> sealed,
  ) async {
    versions[id] = (versions[id] ?? 0) + 1;
    envelopes[id] = Map<String, dynamic>.from(sealed['me'] as Map);
    return {'key_version': versions[id], 'envelope': envelopes[id]};
  }

  @override
  Future<Map<String, dynamic>> getE2eeConversationKey(String id) async {
    final envelope = envelopes[id];
    if (envelope == null) return {'exists': false};
    return {
      'exists': true,
      'key': {'key_version': versions[id], 'envelope': envelope},
      'rekey_required': false,
      'missing_member_ids': const [],
      'gaps': const [],
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SealFakeStorage implements SecureStorage {
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

/// The message row the server would serve for a send of [files] sealed as
/// [payload]: each encrypted file under the generic name, the coarse type and
/// the ciphertext size its wire form carried, with the sealed key beside it.
ChatMessage servedMessage(
  String conversationId,
  EncryptedDmPayload payload,
  List<ChatAttachmentInput> files,
) => ChatMessage(
  id: 'm-$conversationId',
  conversationId: conversationId,
  userId: 'me',
  body: '',
  createdAt: '2026-10-06T00:00:00Z',
  encryptedBody: payload.encryptedBody,
  encryptionNonce: payload.nonce,
  encryptionVersion: 1,
  encryptionKeyVersion: payload.keyVersion,
  attachments: [
    for (final file in files)
      _served(
        file.withSeal(payload.attachmentSeals[file.fileUrl]).toWire(),
        payload.keyVersion,
      ),
  ],
);

ChatMessageAttachment _served(Map<String, dynamic> wire, int keyVersion) =>
    ChatMessageAttachment.fromJson({
      ...wire,
      'id': 'a-${wire['file_url']}',
      'message_id': 'm',
      'uploaded_by': 'me',
      'created_at': '2026-10-06T00:00:00Z',
      'enc_key_version': keyVersion,
    });

extension ForwardedAttachment on ChatMessageAttachment {
  /// The row a forward stores at its destination: the same object, under the
  /// seal the forwarder made for that conversation.
  ChatMessageAttachment forwardedAs(
    Map<String, dynamic> seal,
    int keyVersion,
  ) => ChatMessageAttachment.fromJson({
    ...toJson(),
    'enc_meta': seal['enc_meta'],
    'enc_nonce': seal['enc_nonce'],
    'enc_key_version': keyVersion,
  });
}
