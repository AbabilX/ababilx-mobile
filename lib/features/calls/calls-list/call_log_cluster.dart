import '../data/models/call_log_entry.dart';

/// A run of calls that belong on one row, plus how many there are.
///
/// [lead] is the newest call in the run — the one whose time, mode and avatar
/// the row shows. Everything else in the run is represented only by [count].
class CallLogCluster {
  const CallLogCluster({required this.lead, required this.count});

  final CallLogEntry lead;
  final int count;

  /// More than one call folded in, so the row prints "(3) Missed · 4:12".
  bool get stacked => count > 1;

  /// Stable across pagination: a run is identified by its newest call, and a
  /// run only ever grows at its older end when the next page arrives.
  String get id => lead.id;
}

/// Signal's call-log clustering (`CallEventCache.readNextCallLog`), with our
/// own window.
///
/// Four calls to the same person in ten minutes is one event to a reader and
/// four rows of noise on screen. A child joins the run when it matches the
/// lead on **who**, on **direction**, and on **missed-ness** — Signal's
/// `isEventMatch`, which keeps a missed call from being swallowed by the
/// answered one that followed it, since a missed call is the one thing on this
/// screen somebody is actually looking for.
///
/// The window is compared against the **lead**, never the previous child, so a
/// long chain of calls a few minutes apart cannot drift hours away from the
/// row's own timestamp. Signal uses four hours; ours is one, which is the
/// tighter reading and closer to what WhatsApp shows.
///
/// [calls] must be newest-first, which is the order the server returns. Run
/// this over the whole accumulated list rather than per page: a run split
/// across a page boundary then merges by itself when the next page lands.
List<CallLogCluster> clusterCallLog(
  List<CallLogEntry> calls, {
  Duration window = const Duration(hours: 1),
}) {
  final out = <CallLogCluster>[];
  var i = 0;
  while (i < calls.length) {
    final lead = calls[i];
    var next = i + 1;
    while (next < calls.length && _joins(lead, calls[next], window)) {
      next++;
    }
    out.add(CallLogCluster(lead: lead, count: next - i));
    i = next;
  }
  return out;
}

/// Conversation rather than peer id: it identifies a group room as well as a
/// DM, and a 1:1 call always has one.
bool _joins(CallLogEntry lead, CallLogEntry child, Duration window) =>
    lead.conversationId.isNotEmpty &&
    lead.conversationId == child.conversationId &&
    lead.direction == child.direction &&
    lead.missed == child.missed &&
    lead.startedAt.difference(child.startedAt).abs() <= window;
