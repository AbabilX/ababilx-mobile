import 'dart:convert';

import 'package:drift/drift.dart';

import '../../tiptap_plain_text.dart';
import '../models/chat_message.dart';
import 'chat_local_db.dart';

/// Sort key for a message. The server sends ISO-8601 UTC; an unparseable value
/// sorts to the very beginning rather than crashing the write.
int messageTimeMs(ChatMessage m) =>
    DateTime.tryParse(m.createdAt)?.millisecondsSinceEpoch ?? 0;

/// Local history key. A send is inserted under its clientRef and confirmed
/// under the same key (server id lives in the payload), matching the reference
/// app's insert-then-update. Messages without a client ref keep using server
/// id.
String localMessageRowId(ChatMessage m) {
  final ref = m.clientRef;
  if (ref != null && ref.isNotEmpty) return ref;
  return m.id;
}

/// Message → row. An E2EE DM is written ciphertext-only: its plaintext body is
/// blanked and it contributes nothing to [CachedMessages.searchText], so the
/// decrypted text exists on this device only inside the vault and in memory.
CachedMessagesCompanion messageRow(ChatMessage m) {
  final json = m.toJson();
  if (m.isEncrypted) json['body'] = '';
  // Same rule for the quote: its plaintext was decrypted into memory, and the
  // ciphertext beside it is what belongs on disk.
  final quote = m.quote;
  if (quote != null && quote.isEncrypted && json['quote'] is Map) {
    (json['quote'] as Map)['body'] = '';
  }
  return CachedMessagesCompanion.insert(
    id: localMessageRowId(m),
    conversationId: m.conversationId,
    createdAtMs: messageTimeMs(m),
    threadRootId: Value(m.parentId),
    payloadJson: jsonEncode(json),
    searchText: Value(_searchText(m)),
  );
}

/// Row → message. Returns null for a row that can no longer be decoded (a
/// model change, a truncated write) — the caller treats it as a cache miss.
ChatMessage? messageFromRow(CachedMessage row) {
  try {
    return ChatMessage.fromJson(
      jsonDecode(row.payloadJson) as Map<String, dynamic>,
    );
  } catch (_) {
    return null;
  }
}

List<ChatMessage> messagesFromRows(Iterable<CachedMessage> rows) {
  final out = <ChatMessage>[];
  for (final row in rows) {
    final msg = messageFromRow(row);
    if (msg != null) out.add(msg);
  }
  return out;
}

String _searchText(ChatMessage m) {
  if (m.isEncrypted || m.isDeleted || m.isPending) return '';
  final body = tiptapToPreviewText(m.body);
  final names = m.attachments.map((a) => a.fileName).join(' ');
  return '$body $names'.trim().toLowerCase();
}
