/// The history merge contract — `ababilx-server/docs/history-transfer-v2-protocol.md`
/// section 7 — pinned row by row by `test/fixtures/history_transfer/
/// history-transfer-v2-merge.json`, the same file web's `merge.test.mjs` reads.
///
/// **Not** `keepLocalDuringRecovery`: that helper keeps the local copy on
/// equal revisions, where this contract lets a server-sourced copy win over
/// phone backfill. Two platforms settling one message two ways is exactly
/// what the shared fixture exists to catch.
enum HistoryProvenance { server, phone }

enum HistoryMergeDecision { insert, replace, keep, suppress }

class HistoryMergeMessage {
  const HistoryMergeMessage({
    required this.id,
    required this.conversationId,
    required this.createdAt,
    this.deletedAt,
    this.revision = 0,
    this.contentPurged = false,
  });

  final String id;
  final String conversationId;
  final String createdAt;
  final String? deletedAt;
  final int revision;
  final bool contentPurged;

  factory HistoryMergeMessage.fromJson(Map<String, dynamic> json) =>
      HistoryMergeMessage(
        id: json['id'] as String? ?? '',
        conversationId: json['conversation_id'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
        deletedAt: json['deleted_at'] as String?,
        revision: (json['revision'] as num?)?.toInt() ?? 0,
        contentPurged: json['content_purged'] == true,
      );

  bool get isRetentionPlaceholder => contentPurged;
  bool get isIntentionalDeletion =>
      (deletedAt ?? '').isNotEmpty && !contentPurged;
  bool get isUsable => (deletedAt ?? '').isEmpty && !contentPurged;
}

class HistoryMergeSide {
  const HistoryMergeSide(this.provenance, this.message);

  final HistoryProvenance provenance;
  final HistoryMergeMessage message;
}

/// Microseconds since the epoch; Postgres writes six fractional digits.
int historyTimestampMicros(String value) =>
    DateTime.parse(value).microsecondsSinceEpoch;

bool historyMarkerMatches(
  HistoryMergeMessage message,
  List<Map<String, dynamic>> markers,
) {
  int? created;
  for (final marker in markers) {
    if (marker['conversation_id'] != message.conversationId) continue;
    final messageId = marker['message_id'] as String? ?? '';
    if (messageId.isNotEmpty) {
      if (messageId == message.id) return true;
      continue;
    }
    if (marker['entire_conversation'] == true) return true;
    created ??= historyTimestampMicros(message.createdAt);
    if (created <= historyTimestampMicros(marker['through_at'] as String)) {
      return true;
    }
  }
  return false;
}

HistoryMergeDecision decideHistoryMerge(
  HistoryMergeSide? existing,
  HistoryMergeSide incoming,
  List<Map<String, dynamic>> markers,
) {
  final next = incoming.message;
  if (historyMarkerMatches(next, markers)) return HistoryMergeDecision.suppress;
  if (existing == null) return HistoryMergeDecision.insert;
  final current = existing.message;
  if (next.isIntentionalDeletion) return HistoryMergeDecision.replace;
  if (current.isIntentionalDeletion) return HistoryMergeDecision.keep;
  if (next.isRetentionPlaceholder && current.isUsable) {
    return HistoryMergeDecision.keep;
  }
  if (current.isRetentionPlaceholder && next.isUsable) {
    return HistoryMergeDecision.replace;
  }
  final a = current.revision > 0 ? current.revision : 0;
  final b = next.revision > 0 ? next.revision : 0;
  if (a > 0 && b > 0) {
    if (a != b) {
      return b > a ? HistoryMergeDecision.replace : HistoryMergeDecision.keep;
    }
    if (existing.provenance == incoming.provenance) {
      return HistoryMergeDecision.keep;
    }
    return incoming.provenance == HistoryProvenance.server
        ? HistoryMergeDecision.replace
        : HistoryMergeDecision.keep;
  }
  if (incoming.provenance == HistoryProvenance.phone) {
    return current.isUsable
        ? HistoryMergeDecision.keep
        : HistoryMergeDecision.replace;
  }
  return HistoryMergeDecision.replace;
}
