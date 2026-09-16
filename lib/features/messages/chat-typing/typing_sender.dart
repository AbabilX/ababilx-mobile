import '../../../core/network/ws_client.dart';

/// Reports this device's draft state for one conversation.
///
/// Receivers expire a typist after 5 s, so "typing" is re-sent every 3 s while
/// the text keeps changing. Frames go out with [WsClient.send] and are dropped
/// when the socket is down — a queued "typing" delivered later is a lie.
class ChatTypingSender {
  ChatTypingSender({
    required this.ws,
    required this.conversationId,
    required this.enabled,
  });

  static const resendEvery = Duration(seconds: 3);

  final WsClient ws;
  final String conversationId;
  final bool Function() enabled;
  DateTime? _sentAt;

  void onText(String text) {
    if (text.trim().isEmpty) return stop();
    if (!enabled()) return;
    final now = DateTime.now();
    final last = _sentAt;
    if (last != null && now.difference(last) < resendEvery) return;
    _sentAt = now;
    _send(true);
  }

  void stop() {
    if (_sentAt == null) return;
    _sentAt = null;
    _send(false);
  }

  void _send(bool typing) => ws.send({
    'type': 'chat.typing',
    'conversation_id': conversationId,
    'typing': typing,
  });
}
