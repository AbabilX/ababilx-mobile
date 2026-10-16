import '../data/local/chat_message_row.dart';
import '../data/models/chat_models.dart';

/// How long one page of older history may take before the phone stops
/// waiting and reads its own store instead.
const olderPageTimeout = Duration(seconds: 12);

/// Rows the phone keeps proven-and-stored beyond what is on screen, so the
/// reader never arrives at the edge of what the server has confirmed.
const olderAheadRows = 100;

/// Messages a request for "older than this" can stand on, best first.
///
/// The server takes a message id as its cursor and answers an EMPTY page for
/// an id it no longer has — the same answer as "nothing older". So the id
/// has to be one the server still holds: never an unsent bubble, and never a
/// held message (private chat, or any message under delivery-only, server
/// 0173), which the server lets go once the phones have it. With none left,
/// the conversation reads the store for the session — which, under
/// delivery-only, is where its history lives.
/// A message without thread replies comes first: the server lists by last
/// activity, and only for those is that the moment they were written.
List<ChatMessage> olderAnchors(
  List<ChatMessage> window, {
  int limit = 2,
  int scan = 30,
}) {
  final plain = <ChatMessage>[];
  final threaded = <ChatMessage>[];
  for (final message in window.take(scan)) {
    if (message.isPending || message.heldForPhones || message.id.isEmpty) {
      continue;
    }
    (message.threadCount > 0 ? threaded : plain).add(message);
  }
  return [...plain, ...threaded].take(limit).toList();
}

/// [messages] without anything written before [cutMs].
///
/// A server page can carry a thread root from months back, listed where its
/// newest reply is. Shown now, it would sit at the top of the timeline with
/// nothing between it and today, and become the point scrollback continues
/// from — skipping everything in between. It is stored, and appears in its
/// own place once the reader gets there. Unsent bubbles always stay.
List<ChatMessage> fromCut(List<ChatMessage> messages, int cutMs) {
  if (cutMs <= 0) return messages;
  return [
    for (final message in messages)
      if (message.isPending || messageTimeMs(message) >= cutMs) message,
  ];
}

/// How far back a page read from the store is still checked against the
/// server for edits, reactions and receipts it may have missed. Older than
/// this the store is taken as it is: such changes are rare there, and
/// checking would mean a request for every page of a history the phone
/// already holds — the very thing reading the store is meant to avoid.
const olderRefreshWindow = Duration(days: 30);

/// Whether a page hanging below [anchor] is recent enough to check.
bool worthRefreshing(ChatMessage anchor, DateTime now) =>
    now.millisecondsSinceEpoch - messageTimeMs(anchor) <=
    olderRefreshWindow.inMilliseconds;

/// What the server's copy of a message says that the shown one does not.
enum ServerCopy { same, receipts, newer }

/// Compares by the server's own revision, which moves on an edit, a
/// reaction, an attachment change and a delete. Receipts are the one thing
/// drawn that it does not cover, so they are compared on their own — and
/// need no decryption to apply, since the text beside them did not change.
ServerCopy compareServerCopy(ChatMessage? shown, ChatMessage server) {
  if (shown == null) return ServerCopy.newer;
  if (shown.isPending) return ServerCopy.same;
  if (server.revision > shown.revision) return ServerCopy.newer;
  if (server.revision < shown.revision) return ServerCopy.same;
  final receipts = server.delivery;
  if (receipts != null && receipts != shown.delivery) {
    return ServerCopy.receipts;
  }
  return ServerCopy.same;
}
