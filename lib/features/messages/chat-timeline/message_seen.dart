import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/chat_provider.dart';

/// Whether a message is older than the other side's read time. Strict: a
/// member row can be stamped in the same transaction as the first message.
bool seenByReadTime(String createdAt, String? readUpTo) {
  if (readUpTo == null) return false;
  final sent = DateTime.tryParse(createdAt);
  final read = DateTime.tryParse(readUpTo);
  return sent != null && read != null && sent.isBefore(read);
}

/// The newer of two read times; a late event never moves a tick backwards.
String laterReadTime(String? current, String incoming) {
  final was = current == null ? null : DateTime.tryParse(current);
  final now = DateTime.tryParse(incoming);
  if (was == null) return incoming;
  return now != null && now.isAfter(was) ? incoming : current!;
}

final othersReadAtProvider = Provider.family<String?, String>(
  (ref, conversationId) => ref.watch(
    chatProvider.select(
      (state) => state.conversationById(conversationId)?.othersReadAt,
    ),
  ),
);
