import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/storage/secure_storage.dart';
import '../data/chat_repository.dart';
import '../data/models/chat_message.dart';
import '../data/models/chat_message_quote.dart';
import 'p256_ecdh.dart';

part 'message_vault_codec.dart';
part 'message_vault_identity.dart';
part 'message_vault_keys.dart';
part 'message_vault_legacy.dart';
part 'message_vault_link.dart';

const _vaultAad = 'ababilx-message-vault-v1';

/// What this device can do about secure messages right now.
///
/// [ready] is the resting state and, after the first launch, the only one a
/// user ever sees. [link] means the key has to be handed over from a device
/// that holds it, and [legacy] is the single remaining PIN prompt for accounts
/// that still carry a server-side wrapped key to shed.
enum VaultIdentityState { ready, link, legacy }

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

  /// This account's public identity, for deriving a safety number against a
  /// peer's. Public by construction — it is what the server hands out to
  /// anyone who may message us — so exposing it costs nothing.
  Map<String, dynamic>? get publicIdentity => _publicJwk;

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

  /// Decrypts a quoted message's preview, if it has one and it is ciphertext.
  ///
  /// The quote is resolved by the server from the original row, so in a DM it
  /// arrives encrypted under the same conversation key — and under the
  /// *quoted* sender's id, which the cipher binds into its AAD. Running it back
  /// through [decryptMessage] as a stand-in message reuses the key cache and
  /// the rotation refetch; the stand-in carries no quote of its own, so this
  /// recurses exactly once.
  Future<ChatMessageQuote?> _decryptQuote(
    ChatMessage message,
    String currentUserId,
  ) async {
    final quote = message.quote;
    if (quote == null || !quote.isEncrypted) return null;
    final decrypted = await decryptMessage(
      ChatMessage(
        id: quote.messageId,
        conversationId: message.conversationId,
        userId: quote.userId,
        body: '',
        createdAt: '',
        encryptedBody: quote.encryptedBody,
        encryptionNonce: quote.encryptionNonce,
        encryptionVersion: 1,
        encryptionKeyVersion: quote.encryptionKeyVersion,
      ),
      currentUserId,
    );
    return quote.copyWith(body: decrypted.body);
  }

  Future<ChatMessage> decryptMessage(
    ChatMessage message,
    String currentUserId,
  ) async {
    // An attachment-only DM carries no ciphertext of its own but can still
    // quote one, so the quote is resolved before the outer early-return.
    final quote = await _decryptQuote(message, currentUserId);
    if (!message.isEncrypted) {
      return quote == null ? message : message.copyWith(quote: quote);
    }
    if (!isUnlocked) {
      return message.copyWith(body: 'Encrypted message', quote: quote);
    }
    if (currentUserId.isEmpty) {
      return message.copyWith(body: 'Encrypted message', quote: quote);
    }
    try {
      var key = await _loadKey(message.conversationId, currentUserId);
      // A newer key version means the other side rotated (usually after a PIN
      // reset), so the cached key is stale and worth one refetch.
      if (key != null && (message.encryptionKeyVersion ?? 0) > key.version) {
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
      return message.copyWith(body: utf8.decode(clear), quote: quote);
    } catch (_) {
      return message.copyWith(
        body: 'Unable to decrypt this message',
        quote: quote,
      );
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
