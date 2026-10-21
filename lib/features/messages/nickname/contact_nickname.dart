import '../../../shared/text/display_name.dart';

/// The nicknames this device has set for other people.
///
/// A display name belongs to the account that owns it — we sanitise it, but we
/// do not get to change it. A **nickname** is the other half of that: the name
/// *you* file someone under, on your own phone. Signal keeps the same pair, and
/// it is the only real answer to a name you cannot read — one built from blank
/// glyphs, written in a script you do not have, or shared by three people.
///
/// Keyed by user id, not conversation id, so one nickname follows a person
/// through their DM, every group they are in, and the sender line above their
/// messages.
class ContactNicknames {
  const ContactNicknames([this._byUserId = const {}]);

  final Map<String, String> _byUserId;

  bool get isEmpty => _byUserId.isEmpty;

  /// The nickname set for [userId], or null.
  String? forUser(String? userId) {
    if (userId == null || userId.isEmpty) return null;
    return _byUserId[userId];
  }

  bool hasNickname(String? userId) => forUser(userId) != null;

  /// What to show for a person: their nickname if this device has one, else
  /// their own sanitised display name, else [fallback].
  ///
  /// The nickname goes through [safeDisplayName] too. It is typed on this
  /// phone, but a name pasted out of a chat carries whatever was in it.
  String resolve({
    String? userId,
    String? name,
    String fallback = namelessUserLabel,
  }) {
    final nickname = forUser(userId);
    if (nickname != null) return safeDisplayName(nickname, fallback: fallback);
    return safeDisplayName(name, fallback: fallback);
  }

  ContactNicknames withNickname(String userId, String? nickname) {
    final next = Map<String, String>.from(_byUserId);
    final cleaned = nickname?.trim() ?? '';
    if (cleaned.isEmpty) {
      next.remove(userId);
    } else {
      next[userId] = cleaned;
    }
    return ContactNicknames(next);
  }
}
