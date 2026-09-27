import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/storage/secure_storage.dart';
import '../data/chat_repository.dart';
import '../data/local/chat_key_cache.dart';
import '../data/local/chat_message_store.dart';
import '../../private-chat/private_quote.dart';
import '../../local-backup/restore/restored_body_store.dart';
import '../data/models/chat_message.dart';
import '../data/models/chat_message_quote.dart';
import 'p256_ecdh.dart';
import 'new_chat_history_cleanup.dart';
import 'recovery_key.dart';
import '../data/chat_recovery_api.dart';

part 'message_vault_backfill.dart';
part 'message_vault_backup.dart';
part 'message_vault_decrypt.dart';
part 'message_vault_envelope.dart';
part 'message_vault_ghost.dart';
part 'message_vault_codec.dart';
part 'message_vault_identity.dart';
part 'message_vault_key_cache.dart';
part 'message_vault_key_versions.dart';
part 'message_vault_keys.dart';
part 'message_vault_link.dart';
part 'message_vault_recover.dart';
part 'message_vault_repair.dart';
part 'message_vault_restore.dart';
part 'message_vault_reset.dart';
part 'message_vault_session.dart';
part 'message_vault_local_code.dart';

/// The device's message identity state. New accounts save a recovery code in
/// OS secure storage and proceed directly to chat. `setup` remains only for
/// compatibility with older gate callers; new provisioning returns `ready`.
enum VaultIdentityState { ready, setup, unlock }

class MessageVault {
  MessageVault(this._repo, this._storage, [this._keyCache]);
  final ChatRepository _repo;
  final SecureStorage _storage;

  /// Durable envelope cache. Optional so the FCM background isolate — which
  /// builds a vault by hand and has no Riverpod container — keeps working
  /// untouched; a push arrives over the network anyway, so it loses nothing.
  final ChatKeyCache? _keyCache;
  final _aes = AesGcm.with256bits();
  // The conversation's CURRENT key, for sending. Never populated from disk:
  // a send must seal under the newest version the server knows about, and an
  // old version restored from the cache would be sealed to a retired key.
  final _keys = <String, _DmKey>{};
  // Keys for reading, keyed 'conversationId:version'. Separate from [_keys]
  // for the reason above, and holds retired versions quite legitimately.
  final _readKeys = <String, _DmKey>{};
  // One backfill attempt per conversation per session; a failure clears it.
  final _backfilled = <String>{};
  // A conversation with no readable key caches nothing, so a screenful of
  // messages would fire one identical GET each without this.
  final _keyLoads = <String, Future<_DmKey?>>{};
  // Exact-version fetches in flight, keyed like [_readKeys], so a page of
  // messages sealed under one retired version asks the server once.
  final _versionLoads = <String, Future<_DmKey?>>{};
  // Key resolutions for READING in flight, keyed like [_readKeys]. A cold
  // page decrypts fifty messages at once under one key; without this each
  // read the same envelope off disk and unwrapped it with its own P-256
  // agreement, which is what made a restored chat open slowly.
  final _readKeyLoads = <String, Future<_DmKey?>>{};
  // When the server last said this account holds no envelope for a version.
  final _versionMisses = <String, DateTime>{};
  // Envelopes already reported as unopenable this session, 'conversation:version'.
  final _reportedUnreadable = <String>{};
  // This identity's one pass over the conversations it can refill for others.
  Future<void>? _gapFill;
  P256KeyPair? _identity;
  Map<String, dynamic>? _publicJwk;
  // Legacy gate compatibility. New sessions persist their code in this
  // phone's secure storage and never stage a popup.
  String? _pendingRecoveryCode;
  _PendingFreshStart? _pendingFreshStart;
  int _recoveryEpoch = 0;
  Future<void>? _sessionOperation;
  bool _newChatPending = false;
  bool get isStartingNewChat => _newChatPending;
  Future<void> Function(String userId)? onHistoryReset;

  /// Finds what a private-chat reply quotes (server 0160) in this phone's own
  /// history: the original may be gone from the server, so the reply carries
  /// only its id (`meta.private_quote_id`). Unset in the FCM isolate, which
  /// has no history to look in.
  Future<ChatMessageQuote?> Function(String conversationId, String messageId)?
  privateQuoteLookup;

  /// Text a local backup brought back for a message no key opens any more
  /// (features/local-backup). Asked only after the key path has failed.
  Future<String?> Function(String messageId, String userId)? restoredBodyLookup;

  /// Reads the freshly generated code once and forgets it.
  String? takePendingRecoveryCode() {
    final code = _pendingRecoveryCode;
    _pendingRecoveryCode = null;
    return code;
  }

  bool get isUnlocked => _identity != null && !_newChatPending;

  /// This account's public identity, for deriving a safety number against a
  /// peer's. Public by construction — it is what the server hands out to
  /// anyone who may message us — so exposing it costs nothing.
  Map<String, dynamic>? get publicIdentity => _publicJwk;

  /// Device-only root for encrypted history archives. Recovery codes are
  /// also stored only on this phone; neither secret is sent to the server.
  List<int>? get archiveRootSecret => _identity?.d;

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

  /// Drops every key this process is holding in memory. Both maps go: an
  /// identity change makes the read cache as meaningless as the send cache.
  void _clearKeyMemory() {
    _keys.clear();
    _readKeys.clear();
    // A miss is an answer about one identity's envelopes; the next may hold
    // them. A fetch still in flight checks the identity before it lands, but
    // must not be joined by the next identity's first read either.
    _versionMisses.clear();
    _versionLoads.clear();
    _readKeyLoads.clear();
    _reportedUnreadable.clear();
    _gapFill = null;
  }
}

final messageVaultProvider = Provider<MessageVault>(
  (ref) =>
      MessageVault(
          ref.watch(chatRepositoryProvider),
          const SecureStorage(FlutterSecureStorage()),
          ref.watch(chatKeyCacheProvider),
        )
        ..onHistoryReset = ((userId) => cleanNewChatHistory(ref, userId))
        ..privateQuoteLookup = ((conversationId, messageId) =>
            resolvePrivateQuote(
              ref.read(chatMessageStoreProvider),
              conversationId,
              messageId,
            ))
        ..restoredBodyLookup = ((messageId, userId) =>
            ref.read(restoredBodyStoreProvider).lookup(messageId, userId)),
);
