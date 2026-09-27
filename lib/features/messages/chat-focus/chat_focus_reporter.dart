import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/network/ws_client.dart';

/// The conversation on screen right now, in this process, or null.
///
/// Read by the foreground push handler: a message landing in the chat the user
/// is looking at must not also buzz and raise a tray entry. The FCM background
/// isolate never sees this — and never needs to, since a backgrounded app has
/// nothing on screen.
class ChatScreenFocus {
  const ChatScreenFocus._();

  static String? _current;

  static String? get current => _current;

  static bool isOnScreen(String conversationId) =>
      conversationId.isNotEmpty && _current == conversationId;
}

/// Claims "I am reading [conversationId]" while its screen is up and the app
/// is in the foreground.
///
/// Two halves. Locally, [ChatScreenFocus] lets the foreground push handler
/// drop the entry. On the server, a `chat.focus` frame makes
/// `notify.IsViewingConversation` skip the push altogether — the same frame
/// the web client sends (`use-chat-focus.ts`). The server trusts a claim for
/// 2 minutes, so it is re-sent every 45 s and on every reconnect; a dropped
/// frame is harmless because the server fails open (the push is sent).
class ChatFocusReporter {
  ChatFocusReporter({required this.ws, required this.conversationId});

  static const refreshEvery = Duration(seconds: 45);

  /// Chat screens can stack (a forward opens another chat on top). Only the
  /// top one speaks; popping it hands the claim back to the one below.
  static final List<ChatFocusReporter> _stack = [];

  /// The conversation of the chat screen on top, visible or not — who
  /// "active" goes back to when the screen above it closes.
  static String? get topConversationId =>
      _stack.isEmpty ? null : _stack.last.conversationId;

  final WsClient ws;
  final String conversationId;

  AppLifecycleListener? _lifecycle;
  StreamSubscription<void>? _reconnects;
  Timer? _timer;
  bool _visible = true;

  void start() {
    _stack.add(this);
    _lifecycle = AppLifecycleListener(
      onShow: () => _setVisible(true),
      onResume: () => _setVisible(true),
      onHide: () => _setVisible(false),
      onPause: () => _setVisible(false),
    );
    _reconnects = ws.reconnects.listen((_) => _sync());
    _timer = Timer.periodic(refreshEvery, (_) => _sync());
    _setVisible(
      WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
    );
  }

  void dispose() {
    _lifecycle?.dispose();
    _reconnects?.cancel();
    _timer?.cancel();
    final wasTop = _stack.isNotEmpty && identical(_stack.last, this);
    _stack.remove(this);
    if (!wasTop) return;
    if (_stack.isNotEmpty) return _stack.last._sync();
    ChatScreenFocus._current = null;
    // Leaving releases the claim now rather than after the server's TTL.
    _send('');
  }

  void _setVisible(bool visible) {
    _visible = visible;
    _sync();
  }

  void _sync() {
    if (_stack.isEmpty || !identical(_stack.last, this)) return;
    if (_visible) {
      ChatScreenFocus._current = conversationId;
    } else if (ChatScreenFocus._current == conversationId) {
      ChatScreenFocus._current = null;
    }
    _send(_visible ? conversationId : '');
  }

  void _send(String id) =>
      ws.send({'type': 'chat.focus', 'conversation_id': id});
}
