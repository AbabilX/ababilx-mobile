part of 'message_vault.dart';

/// Thrown when a conversation has no key yet and cannot be given one, because
/// somebody in it has never set up secure messages — there is no public key to
/// seal their envelope to.
///
/// For almost every conversation that is the end of it, and the send fails.
/// The one exception is a group the server marks `plaintext_until_keyed` — a
/// workspace channel converted by the server's migration 0145 that has never
/// had a key. It was plaintext for its whole life, and its members may not
/// all have an identity yet, so its caller may send as it is and the first
/// send after everyone is ready mints the key. The caller decides that from
/// [ChatConversation.plaintextUntilKeyed], never from the conversation type:
/// a group created as a group must not quietly become a plaintext one.
///
/// A [StateError], so every place that already shows a StateError's message
/// keeps doing so.
class ChatKeyNotReady extends StateError {
  ChatKeyNotReady(super.message);
}
