import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';

/// Durable deletion markers also reject stale network responses and backups.
class ChatDeletionFilter {
  String _user = '';
  int revision = 0;
  List<Map<String, dynamic>> records = [];
  final Map<String, Map<String, dynamic>> _conversations = {};
  final Set<String> _messages = {};

  Future<void> load(String user) async {
    if (user.isEmpty || user == _user) return;
    _user = user;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('chat_deletions:$user');
    _set(
      raw == null
          ? []
          : (jsonDecode(raw) as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList(),
    );
  }

  Future<void> replace(List<Map<String, dynamic>> next) async {
    final merged = <String, Map<String, dynamic>>{};
    for (final item in [...records, ...next]) {
      final key = '${item['conversation_id']}:${item['message_id']}';
      final previous = merged[key];
      if (previous == null ||
          DateTime.parse(
            item['deleted_at'] as String,
          ).isAfter(DateTime.parse(previous['deleted_at'] as String))) {
        merged[key] = item;
      }
    }
    _set(merged.values.toList());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_deletions:$_user', jsonEncode(records));
  }

  Future<void> rememberMessage(String conversationId, String messageId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await replace([
      {
        'conversation_id': conversationId,
        'message_id': messageId,
        'through_at': now,
        'deleted_at': now,
        'entire_conversation': false,
      },
    ]);
  }

  void _set(List<Map<String, dynamic>> next) {
    revision++;
    records = next;
    _conversations.clear();
    _messages.clear();
    for (final item in next) {
      final id = item['message_id'] as String? ?? '';
      if (id.isNotEmpty) {
        _messages.add(id);
      } else {
        _conversations[item['conversation_id'] as String] = item;
      }
    }
  }

  bool allows(ChatMessage message) =>
      !message.isDeleted &&
      !_messages.contains(message.id) &&
      allowsTime(
        message.conversationId,
        DateTime.tryParse(message.createdAt)?.microsecondsSinceEpoch ?? 0,
        pending: message.isPending,
      );

  bool allowsTime(
    String conversationId,
    int microseconds, {
    bool pending = false,
  }) {
    final marker = _conversations[conversationId];
    if (marker == null) return true;
    if (marker['entire_conversation'] == true) return false;
    final cutoff = DateTime.parse(
      marker[pending ? 'deleted_at' : 'through_at'] as String,
    );
    return microseconds > cutoff.microsecondsSinceEpoch;
  }

  List<ChatMessage> filter(List<ChatMessage> messages) =>
      messages.where(allows).toList();
}
