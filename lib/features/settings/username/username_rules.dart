/// Handle rules, mirrored from `handlers/me.NormalizeUsername`.
///
/// The server is the authority — it owns the unique index and refuses what it
/// refuses. This copy exists so the Save button can be dead before a round
/// trip, and so the field can say what is wrong while it is being typed. Keep
/// the two in step: a rule that exists only here lets a handle through that
/// comes back 400, and one that exists only there reads as a broken button.
library;

const int usernameMinLength = 3;
const int usernameMaxLength = 32;

/// Handles nobody may claim. A QR code that resolves to `@support` is a
/// phishing tool wearing our branding.
const Set<String> _reservedUsernames = {
  'ababilx', 'admin', 'administrator', 'support', 'help', 'security',
  'billing', 'payments', 'team', 'teams', 'staff', 'system', 'root',
  'me', 'you', 'new', 'settings', 'login', 'signin', 'signup', 'auth',
  'api', 'www', 'official', 'verified', 'moderator', 'mod',
  'null', 'undefined', 'everyone', 'here',
};

/// Folds a typed handle to the stored form: no leading `@`, no surrounding
/// space, lowercase. Identity is case-insensitive, so this is what a QR code
/// carries and what a lookup matches.
String normalizeUsername(String raw) {
  final trimmed = raw.trim().toLowerCase();
  return trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
}

/// The reason a handle is refused, or null when it is fine. The text is shown
/// under the field, so each case says what to change rather than "invalid".
String? usernameError(String raw) {
  final name = normalizeUsername(raw);
  if (name.isEmpty) return null; // Nothing typed yet is not an error.
  if (name.length < usernameMinLength) {
    return 'At least $usernameMinLength characters.';
  }
  if (name.length > usernameMaxLength) {
    return 'At most $usernameMaxLength characters.';
  }
  var prevSeparator = false;
  for (var i = 0; i < name.length; i++) {
    final ch = name[i];
    if (_isAsciiLetterOrDigit(ch)) {
      prevSeparator = false;
      continue;
    }
    if (ch != '.' && ch != '_' && ch != '-') {
      // Letters are ASCII only: a Cyrillic "а" is the same glyph to a reader
      // and a different string to the database, which is an impersonation kit.
      return 'Letters a–z, numbers, and . _ - only.';
    }
    if (i == 0 || i == name.length - 1) {
      return 'Cannot start or end with . _ or -';
    }
    if (prevSeparator) return 'No two of . _ - in a row.';
    prevSeparator = true;
  }
  if (_reservedUsernames.contains(name)) return 'That username is reserved.';
  return null;
}

bool isValidUsername(String raw) =>
    normalizeUsername(raw).isNotEmpty && usernameError(raw) == null;

bool _isAsciiLetterOrDigit(String ch) {
  final code = ch.codeUnitAt(0);
  return (code >= 0x61 && code <= 0x7A) || (code >= 0x30 && code <= 0x39);
}
