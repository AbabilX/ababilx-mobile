part of 'chat_provider.dart';

/// Catching up on whatever the socket missed.
///
/// A WebSocket that dies with the radio closes nothing on this end, so for as
/// long as the client has not noticed, every `chat.message.created` is being
/// delivered to a socket nobody holds. The phone looks connected and the
/// conversation simply stops moving — which is what a pull-to-refresh was
/// papering over, since an HTTP request opens its own connection and works.
///
/// Signal reaches for the same two things when it wakes its connect loop: a
/// live connection, and a fetch. [WsClientRevive.kick] is the connection;
/// this is the fetch, and it deliberately runs on BOTH triggers — a socket that
/// reconnected has a gap by definition, and a socket that survived the app
/// being away may still have dropped frames while the process was frozen.
mixin _ChatResyncMixin
    on Notifier<ChatState>, _ChatFeedMixin, _ChatWsMixin, _ChatActionsMixin {
  /// Re-reads everything a gap could have hidden: the sidebar, the open
  /// conversation, its thread, and anything still queued to send.
  ///
  /// Fire-and-forget on purpose — this runs from a lifecycle callback and from
  /// a stream listener, neither of which has anywhere to report a failure to,
  /// and every branch of it is idempotent.
  void resyncNow() {
    // Before bootstrap there is nothing loaded to be stale, and the sidebar
    // fetch would race the one bootstrap is already making.
    if (!realtimeStarted || isDisposed) return;
    // Older pages read from disk were checked against the server once; a
    // gap means they may have changed since.
    (this as _ChatOlderRefreshMixin).forgetRefreshedOlder();
    unawaited(fetchSidebarSilent());
    final active = state.activeConversationId;
    if (active != null) {
      unawaited(loadFeed(active, force: true));
      final thread = state.threadRootId;
      if (thread != null) {
        unawaited(loadFeed(active, threadRootId: thread, force: true));
      }
    }
    unawaited(retryPendingMessages());
    // Private messages that arrived while the socket was away are only on
    // the server until this phone takes them (server 0160).
    unawaited((this as _ChatPrivateMixin).pullPrivatePending());
  }
}
