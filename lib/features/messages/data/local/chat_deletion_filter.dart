import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';

/// Durable deletion markers also reject stale network responses and backups.
///
/// A conversation marker's `through_at` is two cutoffs in one: what the person
/// deleted, and where their "start fresh" cut the history. Since migration
/// 0164 the server also sends `explicit_through_at`, the deletes alone (null =
/// none; a missing key = an older server, so `through_at` stays the rule).
/// A local backup restore is the one reader that may look past a fresh start.
class ChatDeletionFilter {
  String _user = '';
  int revision = 0;
  List<Map<String, dynamic>> records = [];
  final Map<String, Map<String, dynamic>> _conversations = {};
  final Set<String> _messages = {};

  /// Conversations whose history came back from a local backup past a fresh
  /// start: id -> the marker's `through_at` at that moment. Holds only while
  /// the server has not moved that marker since — another fresh start or a
  /// delete moves it, and the watermark applies again.
  Map<String, String> _restoredPast = {};

  Future<void> load(String user) async {
    if (user.isEmpty || user == _user) return;
    _user = user;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('chat_deletions:$user');
    final past = prefs.getString('chat_deletions_restored:$user');
    _restoredPast = past == null
        ? {}
        : Map<String, String>.from(jsonDecode(past) as Map);
    _set(
      raw == null
          ? []
          : (jsonDecode(raw) as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList(),
    );
  }

  /// Called before a local backup is restored: lets its history through the
  /// fresh-start watermark of every conversation on this device. Deletes
  /// still apply — the explicit cutoff, per-message and whole-chat markers.
  Future<void> admitRestoredHistory() async {
    final next = <String, String>{};
    for (final entry in _conversations.entries) {
      final through = entry.value['through_at'] as String?;
      if (through != null && explicitCutoff(entry.value) != through) {
        next[entry.key] = through;
      }
    }
    _restoredPast = next;
    revision++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_deletions_restored:$_user', jsonEncode(next));
  }

  /// The cutoff of deliberate deletes alone; null when the marker is only a
  /// fresh-start watermark.
  static String? explicitCutoff(Map<String, dynamic> marker) =>
      marker.containsKey('explicit_through_at')
      ? marker['explicit_through_at'] as String?
      : marker['through_at'] as String?;

  Future<void> replace(List<Map<String, dynamic>> next) async {
    final merged = <String, Map<String, dynamic>>{};
    for (final item in [...records, ...next]) {
      final key = '${item['conversation_id']}:${item['message_id']}';
      final previous = merged[key];
      // A tie goes to the later item — the server's copy, which may carry
      // fields (explicit_through_at) a cached one predates.
      if (previous == null ||
          !DateTime.parse(
            item['deleted_at'] as String,
          ).isBefore(DateTime.parse(previous['deleted_at'] as String))) {
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
    final through = marker['through_at'] as String;
    final String? cut = pending
        ? marker['deleted_at'] as String
        : _restoredPast[conversationId] == through
        ? explicitCutoff(marker)
        : through;
    if (cut == null) return true;
    return microseconds > DateTime.parse(cut).microsecondsSinceEpoch;
  }

  List<ChatMessage> filter(List<ChatMessage> messages) =>
      messages.where(allows).toList();
}
