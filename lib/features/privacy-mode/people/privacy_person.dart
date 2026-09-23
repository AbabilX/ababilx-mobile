/// One account's privacy choice about one other person (server migration
/// 0153). [follow] is "no choice": the person follows the account switch.
enum PrivacyPersonMode {
  follow('default'),
  always('always'),
  never('never');

  const PrivacyPersonMode(this.wire);

  /// The server's spelling.
  final String wire;

  static PrivacyPersonMode? fromWire(Object? value) {
    for (final mode in values) {
      if (mode.wire == value) return mode;
    }
    return null;
  }

  /// Whether privacy applies toward the person, given the account switch.
  bool appliesWith({required bool switchOn}) => switch (this) {
    PrivacyPersonMode.follow => switchOn,
    PrivacyPersonMode.always => true,
    PrivacyPersonMode.never => false,
  };
}

/// A stored choice plus enough of the person to draw a list row. Name and
/// avatar are display-only: a choice that arrived from another device
/// carries none until the list is next fetched.
class PrivacyPerson {
  const PrivacyPerson({
    required this.userId,
    required this.mode,
    this.name = '',
    this.username = '',
    this.avatarUrl = '',
  });

  final String userId;
  final PrivacyPersonMode mode;
  final String name;
  final String username;
  final String avatarUrl;

  PrivacyPerson withMode(PrivacyPersonMode next) => PrivacyPerson(
    userId: userId,
    mode: next,
    name: name,
    username: username,
    avatarUrl: avatarUrl,
  );

  /// Null for a row the server would never send (unknown mode, no id).
  static PrivacyPerson? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['user_id'];
    final mode = PrivacyPersonMode.fromWire(json['mode']);
    if (id is! String || id.isEmpty || mode == null) return null;
    if (mode == PrivacyPersonMode.follow) return null;
    return PrivacyPerson(
      userId: id,
      mode: mode,
      name: json['name'] as String? ?? '',
      username: json['username'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
    );
  }

  Map<String, Object> toJson() => {
    'user_id': userId,
    'mode': mode.wire,
    'name': name,
    'username': username,
    'avatar_url': avatarUrl,
  };
}
