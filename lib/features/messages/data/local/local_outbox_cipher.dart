import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/storage/secure_storage.dart';
import '../models/chat_message.dart';

/// Device-only envelope, never sent to the server or placed in message history.
/// Keeps the whole retry payload safe before any conversation-key network I/O.
class LocalOutboxCipher {
  LocalOutboxCipher(this.storage);
  final SecureStorage storage;
  final _aes = AesGcm.with256bits();
  Future<SecretKey>? _key;
  Future<SecretKey> _loadKey() => _key ??= _readKey().whenComplete(() {
    _key = null;
  });
  Future<SecretKey> _readKey() async {
    final saved = await storage.readOutboxKey();
    if (saved != null) return SecretKey(base64Decode(saved));
    final key = await _aes.newSecretKey();
    await storage.writeOutboxKey(base64Encode(await key.extractBytes()));
    return key;
  }

  List<int> _aad(String owner, String conversation, String ref) =>
      utf8.encode(jsonEncode(['local-outbox-v1', owner, conversation, ref]));
  Future<String> seal(ChatMessage message) async {
    final box = await _aes.encrypt(
      utf8.encode(jsonEncode(message.toJson())),
      secretKey: await _loadKey(),
      aad: _aad(
        message.userId,
        message.conversationId,
        message.clientRef ?? message.id,
      ),
    );
    return 'local-v1:${base64Encode(box.concatenation())}';
  }

  Future<ChatMessage> open(
    String payload,
    String owner,
    String conversation,
    String ref,
  ) async {
    final box = SecretBox.fromConcatenation(
      base64Decode(payload.substring('local-v1:'.length)),
      nonceLength: 12,
      macLength: 16,
    );
    final bytes = await _aes.decrypt(
      box,
      secretKey: await _loadKey(),
      aad: _aad(owner, conversation, ref),
    );
    return ChatMessage.fromJson(
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
    );
  }
}

final localOutboxCipherProvider = Provider(
  (ref) => LocalOutboxCipher(const SecureStorage(FlutterSecureStorage())),
);
