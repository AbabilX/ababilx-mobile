import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/storage/secure_storage.dart';
import '../data/chat_repository.dart';
import '../data/models/chat_message.dart';

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
  final _ecdh = Ecdh.p256(length: 32);
  final _aes = AesGcm.with256bits();
  final _keys = <String, _DmKey>{};
  EcKeyPairData? _identity;
  Map<String, dynamic>? _publicJwk;

  bool get isUnlocked => _identity != null;

  Future<bool> hasVault() async =>
      (await _repo.getE2eeVault())['exists'] == true;

  /// Restores the identity protected by this device's OS secure storage.
  /// It is intentionally erased on logout and by an app uninstall.
  Future<bool> restoreTrustedIdentity() async {
    try {
      final saved = await _storage.readMessageVaultIdentity();
      if (saved == null) return false;
      final data = Map<String, dynamic>.from(jsonDecode(saved) as Map);
      final status = await _repo.getE2eeVault();
      if (status['exists'] != true) return false;
      final serverPublic = Map<String, dynamic>.from(
        (status['vault'] as Map)['public_key'] as Map,
      );
      final localPublic = Map<String, dynamic>.from(data['public_key'] as Map);
      if (serverPublic['x'] != localPublic['x'] ||
          serverPublic['y'] != localPublic['y']) {
        await _storage.deleteMessageVaultIdentity();
        return false;
      }
      _identity = _identityFromJwk(
        Map<String, dynamic>.from(data['private_key'] as Map),
      );
      _publicJwk = localPublic;
      _keys.clear();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> setup(String pin) async {
    _validatePin(pin);
    final pair = await _ecdh.newKeyPair();
    final identity = await pair.extract();
    final publicJwk = _publicJwkFromIdentity(identity);
    final privateJwk = {...publicJwk, 'd': _b64(identity.d)};
    final salt = _random(16);
    final nonce = _random(12);
    final key = await _pinKey(pin, salt, _iterations);
    final box = await _aes.encrypt(
      utf8.encode(jsonEncode(privateJwk)),
      secretKey: key,
      nonce: nonce,
      aad: utf8.encode(_vaultAad),
    );
    await _repo.putE2eeVault({
      'public_key': publicJwk,
      'wrapped_private_key': {
        'ciphertext': _b64(_boxBytes(box)),
        'nonce': _b64(nonce),
      },
      'kdf_salt': _b64(salt),
      'kdf_iterations': _iterations,
    });
    _identity = identity;
    _publicJwk = publicJwk;
    _keys.clear();
    await _saveTrustedIdentity(privateJwk, publicJwk);
  }

  Future<void> unlock(String pin) async {
    _validatePin(pin);
    final status = await _repo.getE2eeVault();
    if (status['exists'] != true) {
      throw StateError('Set up your message PIN first');
    }
    final vault = Map<String, dynamic>.from(status['vault'] as Map);
    final wrapped = Map<String, dynamic>.from(
      vault['wrapped_private_key'] as Map,
    );
    try {
      final key = await _pinKey(
        pin,
        _bytes(vault['kdf_salt'] as String),
        (vault['kdf_iterations'] as num).toInt(),
      );
      final clear = await _aes.decrypt(
        _box(wrapped['ciphertext'] as String, wrapped['nonce'] as String),
        secretKey: key,
        aad: utf8.encode(_vaultAad),
      );
      final jwk = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(clear)) as Map,
      );
      _identity = _identityFromJwk(jwk);
      _publicJwk = Map<String, dynamic>.from(vault['public_key'] as Map);
      _keys.clear();
      await _saveTrustedIdentity(jwk, _publicJwk!);
    } catch (_) {
      throw StateError('Incorrect message PIN');
    }
  }

  void lock() {
    _identity?.destroy();
    _identity = null;
    _publicJwk = null;
    _keys.clear();
  }

  Future<void> _saveTrustedIdentity(
    Map<String, dynamic> privateJwk,
    Map<String, dynamic> publicJwk,
  ) => _storage.writeMessageVaultIdentity(
    jsonEncode({'private_key': privateJwk, 'public_key': publicJwk}),
  );

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
    final nonce = _random(12);
    final box = await _aes.encrypt(
      utf8.encode(text),
      secretKey: key.key,
      nonce: nonce,
      aad: utf8.encode(
        'ababilx-dm-v1:$conversationId:${key.version}:$currentUserId',
      ),
    );
    return EncryptedDmPayload(
      encryptedBody: _b64(_boxBytes(box)),
      nonce: _b64(nonce),
      keyVersion: key.version,
    );
  }

  Future<EncryptedDmPayload> encryptExisting({
    required String conversationId,
    required String text,
    required String currentUserId,
  }) async {
    final key = await _loadKey(conversationId, currentUserId);
    if (key == null) throw StateError('Secure message key is unavailable');
    final nonce = _random(12);
    final box = await _aes.encrypt(
      utf8.encode(text),
      secretKey: key.key,
      nonce: nonce,
      aad: utf8.encode(
        'ababilx-dm-v1:$conversationId:${key.version}:$currentUserId',
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
    try {
      final key = await _loadKey(message.conversationId, currentUserId);
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

  Future<_DmKey> _loadOrCreateKey(
    String conversationId,
    String self,
    String peer,
  ) async {
    final loaded = await _loadKey(conversationId, self);
    if (loaded != null) return loaded;
    final identity = _identity;
    final publicJwk = _publicJwk;
    if (identity == null || publicJwk == null) {
      throw StateError('Enter your message PIN first');
    }
    final dmKey = await _aes.newSecretKey();
    final peerResult = await _repo.getE2eePublicKey(peer);
    final peerPublic = Map<String, dynamic>.from(
      peerResult['public_key'] as Map,
    );
    final envelopes = <String, dynamic>{
      self: await _wrapKey(dmKey, self, publicJwk),
      peer: await _wrapKey(dmKey, peer, peerPublic),
    };
    final saved = await _repo.createE2eeConversationKey(
      conversationId,
      envelopes,
    );
    final entry = _DmKey(
      version: (saved['key_version'] as num).toInt(),
      key: await _unwrapKey(
        Map<String, dynamic>.from(saved['envelope'] as Map),
        self,
      ),
    );
    _keys[conversationId] = entry;
    return entry;
  }

  Future<_DmKey?> _loadKey(String conversationId, String self) async {
    final cached = _keys[conversationId];
    if (cached != null) return cached;
    if (_identity == null) {
      return null;
    }
    final status = await _repo.getE2eeConversationKey(conversationId);
    if (status['exists'] != true) return null;
    final key = Map<String, dynamic>.from(status['key'] as Map);
    final entry = _DmKey(
      version: (key['key_version'] as num).toInt(),
      key: await _unwrapKey(
        Map<String, dynamic>.from(key['envelope'] as Map),
        self,
      ),
    );
    _keys[conversationId] = entry;
    return entry;
  }

  Future<Map<String, dynamic>> _wrapKey(
    SecretKey key,
    String recipient,
    Map<String, dynamic> publicJwk,
  ) async {
    final ephemeral = await _ecdh.newKeyPair();
    final ephemeralData = await ephemeral.extract();
    final nonce = _random(12);
    final wrappingKey = await _envelopeKey(ephemeralData, publicJwk);
    final box = await _aes.encrypt(
      await key.extractBytes(),
      secretKey: wrappingKey,
      nonce: nonce,
      aad: utf8.encode('ababilx-dm-key-v1:$recipient'),
    );
    return {
      'ephemeral_public_key': _publicJwkFromIdentity(ephemeralData),
      'nonce': _b64(nonce),
      'ciphertext': _b64(_boxBytes(box)),
    };
  }

  Future<SecretKey> _unwrapKey(
    Map<String, dynamic> envelope,
    String userId,
  ) async {
    final identity = _identity;
    if (identity == null) {
      throw StateError('Enter your message PIN first');
    }
    final key = await _envelopeKey(
      identity,
      Map<String, dynamic>.from(envelope['ephemeral_public_key'] as Map),
    );
    final clear = await _aes.decrypt(
      _box(envelope['ciphertext'] as String, envelope['nonce'] as String),
      secretKey: key,
      aad: utf8.encode('ababilx-dm-key-v1:$userId'),
    );
    return SecretKey(clear);
  }

  Future<SecretKey> _envelopeKey(
    EcKeyPair private,
    Map<String, dynamic> remote,
  ) async {
    final secret = await _ecdh.sharedSecretKey(
      keyPair: private,
      remotePublicKey: EcPublicKey(
        x: _bytes(remote['x'] as String),
        y: _bytes(remote['y'] as String),
        type: KeyPairType.p256,
      ),
    );
    return SecretKey((await Sha256().hash(await secret.extractBytes())).bytes);
  }

  Future<SecretKey> _pinKey(String pin, List<int> salt, int iterations) =>
      Pbkdf2.hmacSha256(
        iterations: iterations,
        bits: 256,
      ).deriveKeyFromPassword(password: pin, nonce: salt);

  EcKeyPairData _identityFromJwk(Map<String, dynamic> jwk) => EcKeyPairData(
    d: _bytes(jwk['d'] as String),
    x: _bytes(jwk['x'] as String),
    y: _bytes(jwk['y'] as String),
    type: KeyPairType.p256,
  );
  Map<String, dynamic> _publicJwkFromIdentity(EcKeyPairData key) => {
    'kty': 'EC',
    'crv': 'P-256',
    'x': _b64(key.x),
    'y': _b64(key.y),
    'ext': true,
    'key_ops': <String>[],
  };
  SecretBox _box(String cipherText, String nonce) {
    final all = _bytes(cipherText);
    return SecretBox(
      all.sublist(0, all.length - 16),
      nonce: _bytes(nonce),
      mac: Mac(all.sublist(all.length - 16)),
    );
  }

  List<int> _boxBytes(SecretBox box) => [...box.cipherText, ...box.mac.bytes];
  List<int> _random(int length) =>
      List<int>.generate(length, (_) => Random.secure().nextInt(256));
  String _b64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');
  List<int> _bytes(String value) =>
      base64Url.decode(base64Url.normalize(value));
  void _validatePin(String pin) {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw ArgumentError('Use a 6-digit message PIN');
    }
  }
}

class _DmKey {
  const _DmKey({required this.version, required this.key});
  final int version;
  final SecretKey key;
}

final messageVaultProvider = Provider<MessageVault>(
  (ref) => MessageVault(
    ref.watch(chatRepositoryProvider),
    const SecureStorage(FlutterSecureStorage()),
  ),
);
