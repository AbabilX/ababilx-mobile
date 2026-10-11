import 'models/chat_models.dart';

/// Which sends are on their way right now, and why the last attempt of each
/// one failed.
///
/// A pending message is written to disk as "sending" before its request is
/// made, and that row is never rewritten when the request fails. Read back
/// later, it would show "Sending…" for good, with no way to send it again.
/// A pending row whose send is not in this set is not being sent by anyone.
class SendTracker {
  final _inFlight = <String>{};
  final _errors = <String, Object>{};

  void begin(String clientRef) {
    _inFlight.add(clientRef);
    _errors.remove(clientRef);
  }

  void end(String clientRef, {Object? error}) {
    _inFlight.remove(clientRef);
    if (error != null) _errors[clientRef] = error;
  }

  /// Why the last attempt of [clientRef] failed, if it did.
  Object? errorOf(String clientRef) => _errors[clientRef];

  /// [messages] as read from disk, with every send nobody is making shown
  /// as failed, so it can be tapped to send again.
  List<ChatMessage> settle(List<ChatMessage> messages) {
    if (!messages.any(_stale)) return messages;
    return [
      for (final m in messages)
        _stale(m) ? m.copyWith(sendStatus: MessageSendStatus.failed) : m,
    ];
  }

  bool _stale(ChatMessage m) =>
      m.sendStatus == MessageSendStatus.sending &&
      !_inFlight.contains(m.clientRef ?? m.id);
}
