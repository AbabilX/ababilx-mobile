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
          .where(
            (m) => m.sendStatus == MessageSendStatus.sent && m.id.isNotEmpty,
          )
          .map((m) {
            final payload = m.toJson();
            if (m.isEncrypted) payload['body'] = '';
            return <String, Object?>{
              'id': m.id,
              'conversationId': m.conversationId,
              'createdAtMs': messageTimeMs(m),
              'threadRootId': m.parentId,
              'payloadJson': jsonEncode(payload),
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

  Future<void> clearConversation(String conversationId) =>
      _channel.invokeMethod<void>('clearConversation', {
        'conversationId': conversationId,
      });

  Future<void> clearAll() => _channel.invokeMethod<void>('clearAll');
}
