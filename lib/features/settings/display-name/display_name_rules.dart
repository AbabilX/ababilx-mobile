/// Client-side mirror of the server's name rules.
///
/// The server is still the authority — `NormalizeDisplayName` in
/// `ababilx-server/handlers/me/display_name.go` runs on every write and its
/// answer is what gets stored. This copy exists so the Save button and the
/// character counter can react as the user types, instead of round-tripping to
/// learn the name was empty. Keep the two in step; the Go file carries the
/// reasoning for each rule.
library;

/// Counted in runes, so a Bengali or emoji name gets the same allowance as an
/// ASCII one.
const int displayNameMaxRunes = 50;

/// Zero-width and direction-flipping characters: they render as nothing but
/// change how the rest of the name reads.
///
/// U+200D (ZWJ) and U+200C (ZWNJ) are deliberately absent — the first holds
/// emoji sequences together, the second is a real letter-shaping character in
/// Bengali, Persian and Arabic.
final _invisible = RegExp(
  r'[\u200B\u200E\u200F\u202A-\u202E\u2066-\u2069\uFEFF]',
);

/// Control characters that are not whitespace. Tab, newline and carriage
/// return are left to [_whitespace], which turns them into a single space.
final _control = RegExp(r'[\x00-\x08\x0E-\x1F\x7F]');

final _whitespace = RegExp(r'\s+');

/// Collapses whitespace runs to one space, drops invisibles and non-whitespace
/// controls, and trims. May return an empty string — see [isValidDisplayName].
String normalizeDisplayName(String raw) => raw
    .replaceAll(_invisible, '')
    .replaceAll(_control, '')
    .replaceAll(_whitespace, ' ')
    .trim();

/// Whether [raw] would be accepted. Over-length is invalid rather than
/// truncated: the user should see their own name refused, not silently cut.
bool isValidDisplayName(String raw) {
  final name = normalizeDisplayName(raw);
  return name.isNotEmpty && name.runes.length <= displayNameMaxRunes;
}

/// Runes remaining before the cap, floored at zero — the counter only appears
/// when the user is close, so a negative would never render anyway.
int displayNameRunesLeft(String raw) {
  final used = normalizeDisplayName(raw).runes.length;
  final left = displayNameMaxRunes - used;
  return left < 0 ? 0 : left;
}
