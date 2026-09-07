import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/chat_message.dart';
import 'chat_message_row.dart';

/// Thin Flutter bridge to Android's Keystore-backed SQLCipher message store.
class AndroidChatMessageStore {
  const AndroidChatMessageStore();

  static const _channel = MethodChannel('com.ababilx.app/chat_store');

  Future<void> upsert(List<ChatMessage> messages) async {
    final rows = _encodedRows(messages);
    if (rows.isEmpty) return;
    await _channel.invokeMethod<void>('upsert', {'rows': rows});
  }

  Future<bool> isLegacyMigrated(String scope) async =>
      await _channel.invokeMethod<bool>('isLegacyMigrated', {'scope': scope}) ??
      false;

  Future<void> migrateLegacy(String scope, List<ChatMessage> messages) =>
      _channel.invokeMethod<void>('migrateLegacy', {
        'scope': scope,
        'rows': _encodedRows(messages),
      });

  List<Map<String, Object?>> _encodedRows(List<ChatMessage> messages) =>
      messages
          .where((m) => m.id.isNotEmpty)
          .map((m) {
            final payload = m.toJson();
            if (m.isEncrypted) payload['body'] = '';
            return <String, Object?>{
              'id': localMessageRowId(m),
              'conversationId': m.conversationId,
              'createdAtMs': messageTimeMs(m),
              'threadRootId': m.parentId,
              'payloadJson': jsonEncode(payload),
              'payloadId': m.id,
            };
          })
          .toList(growable: false);

  Future<List<ChatMessage>> page(
    String conversationId, {
    required int limit,
    int? beforeMs,
    String? beforeId,
    String? threadRootId,
  }) async {
    final payloads = await _channel.invokeListMethod<String>('page', {
      'conversationId': conversationId,
      'limit': limit,
      'beforeMs': beforeMs,
      'beforeId': beforeId,
      'threadRootId': threadRootId,
    });
    return _decode(payloads);
  }

  List<ChatMessage> _decode(List<String>? payloads) {
    final messages = <ChatMessage>[];
    for (final payload in payloads ?? const <String>[]) {
      try {
        messages.add(
          ChatMessage.fromJson(jsonDecode(payload) as Map<String, dynamic>),
        );
      } catch (_) {
        // A corrupt cache row is a cache miss, never a conversation failure.
      }
    }
    return messages;
  }

  Future<List<ChatMessage>> exportPage({
    int? afterMs,
    String? afterId,
    required int limit,
  }) async {
    final payloads = await _channel.invokeListMethod<String>('exportPage', {
      'afterMs': afterMs,
      'afterId': afterId,
      'limit': limit,
    });
    return _decode(payloads);
  }

  Future<bool> hasOlderThan(
    String conversationId,
    int beforeMs, {
    String? beforeId,
  }) async =>
      await _channel.invokeMethod<bool>('hasOlder', {
        'conversationId': conversationId,
        'beforeMs': beforeMs,
        'beforeId': beforeId,
      }) ??
      false;

  Future<void> remove(String messageId) =>
      _channel.invokeMethod<void>('remove', {'messageId': messageId});

  Future<List<ChatMessage>> listUnsent() async {
    final payloads = await _channel.invokeListMethod<String>('unsent');
    final messages = <ChatMessage>[];
    for (final payload in payloads ?? const <String>[]) {
      try {
        final message = ChatMessage.fromJson(
          jsonDecode(payload) as Map<String, dynamic>,
        );
        if (message.isPending) messages.add(message);
      } catch (_) {}
    }
    return messages;
  }

  Future<void> clearConversation(String conversationId) =>
      _channel.invokeMethod<void>('clearConversation', {
        'conversationId': conversationId,
      });

  Future<void> clearAll() => _channel.invokeMethod<void>('clearAll');
}
