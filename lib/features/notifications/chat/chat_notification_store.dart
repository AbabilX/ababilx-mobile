import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One line of a conversation's notification history.
///
/// [text] is plaintext and lives only in the notification store, which is
/// cleared as soon as the conversation is opened or the tray entry is
/// dismissed. Nothing here is a substitute for the message cache.
class ChatNotificationMessage {
  const ChatNotificationMessage({
    required this.messageId,
    required this.sender,
    required this.text,
    required this.sentAt,
    this.fromMe = false,
  });

  factory ChatNotificationMessage.fromJson(Map<String, dynamic> json) =>
      ChatNotificationMessage(
        messageId: json['id']?.toString() ?? '',
        sender: json['sender']?.toString() ?? '',
        text: json['text']?.toString() ?? '',
        sentAt: DateTime.fromMillisecondsSinceEpoch(
          int.tryParse(json['at']?.toString() ?? '') ??
              DateTime.now().millisecondsSinceEpoch,
        ),
        fromMe: json['me'] == true,
      );

  final String messageId;
  final String sender;
  final String text;
  final DateTime sentAt;
  final bool fromMe;

  Map<String, dynamic> toJson() => {
    'id': messageId,
    'sender': sender,
    'text': text,
    'at': sentAt.millisecondsSinceEpoch,
    'me': fromMe,
  };

  ChatNotificationMessage copyWith({String? text}) => ChatNotificationMessage(
    messageId: messageId,
    sender: sender,
    text: text ?? this.text,
    sentAt: sentAt,
    fromMe: fromMe,
  );
}

class ChatNotificationUpsert {
  const ChatNotificationUpsert({
    required this.messages,
    required this.inserted,
  });

  final List<ChatNotificationMessage> messages;
  final bool inserted;
}

/// The messages currently shown in one conversation's tray entry.
///
/// Android's MessagingStyle needs the whole visible thread on every update, so
/// the lines are kept outside the widget tree — the FCM background isolate, the
/// notification-action isolate and the app all write here.
/// [SharedPreferencesAsync] is deliberate: it reads through to the platform
/// every time instead of caching, so one isolate always sees what another wrote.
class ChatNotificationStore {
  const ChatNotificationStore._();

  static const _prefix = 'chat_notif_v1_';

  /// Android collapses a MessagingStyle notification to a handful of lines;
  /// keeping more only grows the payload the plugin has to serialize.
  static const _maxMessages = 8;

  /// Built per call rather than held: the instance binds to whatever platform
  /// backend existed when it was constructed, and this store is used from
  /// isolates that come and go.
  static SharedPreferencesAsync get _prefs => SharedPreferencesAsync();

  static String _key(String conversationId) => '$_prefix$conversationId';

  static Future<List<ChatNotificationMessage>> read(
    String conversationId,
  ) async {
    try {
      final raw = await _prefs.getString(_key(conversationId));
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ChatNotificationMessage.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Adds [message], or rewrites the line with the same `messageId` in place.
  ///
  /// The rewrite is what upgrades a placeholder to the decrypted text without
  /// the tray showing the message twice.
  static Future<List<ChatNotificationMessage>> upsert(
    String conversationId,
    ChatNotificationMessage message,
  ) async => (await upsertDetailed(conversationId, message)).messages;

  /// [inserted] is false for an at-least-once redelivery of the same message.
  /// The presenter uses it to update content without buzzing again.
  static Future<ChatNotificationUpsert> upsertDetailed(
    String conversationId,
    ChatNotificationMessage message,
  ) async {
    final messages = List<ChatNotificationMessage>.from(
      await read(conversationId),
    );
    final at = messages.indexWhere((m) => m.messageId == message.messageId);
    if (at >= 0) {
      messages[at] = message;
    } else {
      messages.add(message);
    }
    messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    final trimmed = messages.length <= _maxMessages
        ? messages
        : messages.sublist(messages.length - _maxMessages);
    try {
      await _prefs.setString(
        _key(conversationId),
        jsonEncode(trimmed.map((m) => m.toJson()).toList()),
      );
    } catch (_) {
      // A history that cannot be persisted still shows this one message.
    }
    return ChatNotificationUpsert(messages: trimmed, inserted: at < 0);
  }

  static Future<void> clear(String conversationId) async {
    try {
      await _prefs.remove(_key(conversationId));
    } catch (_) {}
  }
}
