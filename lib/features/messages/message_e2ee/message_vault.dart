import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/storage/secure_storage.dart';
import '../data/chat_repository.dart';
import '../data/models/chat_message.dart';
import 'p256_ecdh.dart';

part 'message_vault_codec.dart';
part 'message_vault_identity.dart';
part 'message_vault_keys.dart';

const _vaultAad = 'ababilx-message-vault-v1';
const _iterations = 600000;

class EncryptedDmPayload {
  const EncryptedDmPayload({
    required this.encryptedBody,
    required this.nonce,
    required this.keyVersion,
  });
  final String encryptedBody;
  final String nonce;
  final int keyVersion;
}

class MessageVault {
  MessageVault(this._repo, this._storage);
  final ChatRepository _repo;
  final SecureStorage _storage;
  final _aes = AesGcm.with256bits();
  final _keys = <String, _DmKey>{};
  P256KeyPair? _identity;
  Map<String, dynamic>? _publicJwk;

  bool get isUnlocked => _identity != null;

  Future<EncryptedDmPayload> encryptNew({
    required String conversationId,
    required String text,
    required String currentUserId,
    required String peerUserId,
  }) async {
    final key = await _loadOrCreateKey(
      conversationId,
      currentUserId,
      peerUserId,
    );
    return _seal(conversationId, text, currentUserId, key);
  }

  Future<EncryptedDmPayload> encryptExisting({
    required String conversationId,
    required String text,
    required String currentUserId,
  }) async {
    final key = await _loadKey(conversationId, currentUserId);
    if (key == null) throw StateError('Secure message key is unavailable');
    return _seal(conversationId, text, currentUserId, key);
  }

  Future<EncryptedDmPayload> _seal(
    String conversationId,
    String text,
    String senderId,
    _DmKey key,
  ) async {
    final nonce = _random(12);
    final box = await _aes.encrypt(
      utf8.encode(text),
      secretKey: key.key,
      nonce: nonce,
      aad: utf8.encode(
        'ababilx-dm-v1:$conversationId:${key.version}:$senderId',
      ),
    );
    return EncryptedDmPayload(
      encryptedBody: _b64(_boxBytes(box)),
      nonce: _b64(nonce),
      keyVersion: key.version,
    );
  }

  Future<ChatMessage> decryptMessage(
    ChatMessage message,
    String currentUserId,
  ) async {
    if (!message.isEncrypted) return message;
    if (!isUnlocked) return message.copyWith(body: 'Encrypted message');
    if (currentUserId.isEmpty) {
      return message.copyWith(body: 'Encrypted message');
    }
    try {
      var key = await _loadKey(message.conversationId, currentUserId);
      // A newer key version means the other side rotated (usually after a PIN
      // reset), so the cached key is stale and worth one refetch.
      if (key != null &&
          (message.encryptionKeyVersion ?? 0) > key.version) {
        key = await _loadKey(
          message.conversationId,
          currentUserId,
          refresh: true,
        );
      }
      if (key == null || key.version != message.encryptionKeyVersion) {
        throw StateError('Secure message key is unavailable');
      }
      final clear = await _aes.decrypt(
        _box(message.encryptedBody!, message.encryptionNonce!),
        secretKey: key.key,
        aad: utf8.encode(
          'ababilx-dm-v1:${message.conversationId}:${key.version}:${message.userId}',
        ),
      );
      return message.copyWith(body: utf8.decode(clear));
    } catch (_) {
      return message.copyWith(body: 'Unable to decrypt this message');
    }
  }

  Future<List<ChatMessage>> decryptMessages(
    List<ChatMessage> messages,
    String currentUserId,
  ) => Future.wait(messages.map((m) => decryptMessage(m, currentUserId)));
}

final messageVaultProvider = Provider<MessageVault>(
  (ref) => MessageVault(
    ref.watch(chatRepositoryProvider),
    const SecureStorage(FlutterSecureStorage()),
  ),
);
