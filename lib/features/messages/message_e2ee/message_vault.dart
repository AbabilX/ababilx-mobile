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
import 'recovery_key.dart';

part 'message_vault_backfill.dart';
part 'message_vault_decrypt.dart';
part 'message_vault_envelope.dart';
part 'message_vault_codec.dart';
part 'message_vault_identity.dart';
part 'message_vault_keys.dart';
part 'message_vault_link.dart';
part 'message_vault_recover.dart';
part 'message_vault_reset.dart';

/// What this device can do about secure messages right now.
///
/// [ready] is the resting state and, after the first launch, the only one a
/// user ever sees. [setup] means a recovery code was just generated and has to
/// be shown once — the only moment it can be, since nothing keeps a copy.
/// [unlock] is a device that does not hold the key: it needs that code, because
/// AbabilX has no copy of the key to hand over. That is the trade for
/// end-to-end encryption.
enum VaultIdentityState { ready, setup, unlock }

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
  // One backfill attempt per conversation per session; a failure clears it.
  final _backfilled = <String>{};
  // A conversation with no readable key caches nothing, so a screenful of
  // messages would fire one identical GET each without this.
  final _keyLoads = <String, Future<_DmKey?>>{};
  P256KeyPair? _identity;
  Map<String, dynamic>? _publicJwk;
  // A recovery code that has been generated but not yet shown to its owner.
  // It lives here and nowhere else — never in secure storage, never on the
  // server — because anything durable would leave a key-equivalent on disk,
  // which is the one thing this scheme exists to avoid.
  String? _pendingRecoveryCode;
  _PendingFreshStart? _pendingFreshStart;

  /// Reads the freshly generated code once and forgets it.
  String? takePendingRecoveryCode() {
    final code = _pendingRecoveryCode;
    _pendingRecoveryCode = null;
    return code;
  }

  bool get isUnlocked => _identity != null;

  /// This account's public identity, for deriving a safety number against a
  /// peer's. Public by construction — it is what the server hands out to
  /// anyone who may message us — so exposing it costs nothing.
  Map<String, dynamic>? get publicIdentity => _publicJwk;

  Future<EncryptedDmPayload> encryptNew({
    required String conversationId,
    required String text,
    required String currentUserId,
  }) async {
    final key = await _loadOrCreateKey(conversationId, currentUserId);
    return _seal(conversationId, text, currentUserId, key);
  }

  Future<EncryptedDmPayload> encryptExisting({
    required String conversationId,
    required String text,
    required String currentUserId,
  }) async {
    final key = await _loadKey(conversationId, currentUserId);
    // A stale key is one somebody in the conversation can no longer read, so
    // re-sealing under it would make the edit permanently unreadable to them.
    // Rotating here would leave the ORIGINAL message unreadable to the same
    // people, so an edit refuses rather than re-keying.
    if (key == null || key.stale) {
      throw StateError('Secure message key is unavailable');
    }
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
}

final messageVaultProvider = Provider<MessageVault>(
  (ref) => MessageVault(
    ref.watch(chatRepositoryProvider),
    const SecureStorage(FlutterSecureStorage()),
  ),
);
