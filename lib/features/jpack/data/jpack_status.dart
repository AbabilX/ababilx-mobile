import '../../messages/data/models/chat_models.dart';

/// A JPack not opened within this long after it was sent can no longer be
/// claimed.
const jpackLifetime = Duration(hours: 48);

/// Where a JPack stands, from the point of view of this phone.
enum JPackStatus {
  /// Received, not opened, still inside the 48 hours.
  claimable,

  /// Received and opened on this phone.
  opened,

  /// Received, never opened, and the 48 hours are over.
  expired,

  /// Ours, still inside the 48 hours.
  sent,

  /// Ours, and the claim period is over. Without a server this phone cannot
  /// know whether it was opened in time, so it does not say "expired".
  claimClosed,
}

/// The server's `created_at` — the one clock both phones agree on. A pending
/// send carries this phone's own time, which is close enough for a bubble
/// that is seconds old.
DateTime? jpackSentAt(ChatMessage message) =>
    DateTime.tryParse(message.createdAt)?.toUtc();

DateTime? jpackExpiresAt(ChatMessage message) =>
    jpackSentAt(message)?.add(jpackLifetime);

/// Time left to open it; zero once expired, null when the send time is
/// unknown (such a JPack never expires rather than expiring by mistake).
Duration? jpackTimeLeft(ChatMessage message, {DateTime? now}) {
  final expires = jpackExpiresAt(message);
  if (expires == null) return null;
  final left = expires.difference((now ?? DateTime.now()).toUtc());
  return left.isNegative ? Duration.zero : left;
}

bool jpackIsExpired(ChatMessage message, {DateTime? now}) =>
    jpackTimeLeft(message, now: now) == Duration.zero;

/// Opening beats expiry: a JPack opened in time stays opened forever.
JPackStatus jpackStatus({
  required bool isOwn,
  required bool claimed,
  required bool expired,
}) {
  if (isOwn) return expired ? JPackStatus.claimClosed : JPackStatus.sent;
  if (claimed) return JPackStatus.opened;
  return expired ? JPackStatus.expired : JPackStatus.claimable;
}
