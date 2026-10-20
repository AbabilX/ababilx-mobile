import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calls/data/models/call_log_entry.dart';
import '../../calls/providers/call_log_provider.dart';
import 'home_chats.dart';

/// One person this account calls with often.
class FrequentCaller {
  const FrequentCaller({required this.latest, required this.count});

  /// Their newest call: name, picture, conversation and time come from it.
  final CallLogEntry latest;
  final int count;
}

/// 1:1 calls grouped by conversation, most calls first, newest breaking a
/// tie. At least two calls: one call is history, not a habit. Group calls
/// are left out — a room is not somebody you ring.
List<FrequentCaller> frequentCallers(List<CallLogEntry> calls, {int max = 6}) {
  final byChat = <String, List<CallLogEntry>>{};
  for (final c in calls) {
    if (c.isGroup || c.conversationId.isEmpty) continue;
    (byChat[c.conversationId] ??= []).add(c);
  }
  final callers =
      [
        for (final list in byChat.values)
          if (list.length >= 2)
            FrequentCaller(
              latest: list.reduce(
                (a, b) => a.startedAt.isAfter(b.startedAt) ? a : b,
              ),
              count: list.length,
            ),
      ]..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        return byCount != 0
            ? byCount
            : b.latest.startedAt.compareTo(a.latest.startedAt);
      });
  return callers.take(max).toList();
}

/// Read from the call log Talks keeps — the phone's saved page first, so
/// this draws offline and costs no request of its own. A chat that is locked
/// or gone is left out, as everywhere on Home.
final homeFrequentCallersProvider = Provider.autoDispose<List<FrequentCaller>>((
  ref,
) {
  final calls = ref.watch(callLogProvider.select((s) => s.calls));
  final chats = ref.watch(homeConversationsProvider);
  return [
    for (final c in frequentCallers(calls))
      if (homeConversationById(chats, c.latest.conversationId) != null) c,
  ];
});
