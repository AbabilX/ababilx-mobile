import '../../../core/network/friendly_error.dart';

/// The one sentence a failed share is allowed to show.
///
/// Order matters, and it is not arbitrary. A `StateError` out of the message
/// vault already carries a sentence written for a person — "This person must
/// set up secure messages…" — and names the destination that cannot be sealed
/// for, which is worth far more than a generic failure. A handler's own
/// `message` is deliberate in the same way. Only when neither exists is it
/// worth guessing from the transport, and a raw exception is never shown.
String shareErrorMessage(Object error) {
  if (error is StateError) {
    final message = error.message.trim();
    if (message.isNotEmpty) return message;
  }
  final server = serverErrorMessage(error);
  if (server != null) return server;
  if (isOfflineError(error)) {
    return 'No internet connection. Please try again once you are back online.';
  }
  return 'Could not send. Try again.';
}
