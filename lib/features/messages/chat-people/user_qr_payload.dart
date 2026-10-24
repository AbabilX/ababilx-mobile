import '../../settings/username/username_rules.dart';

/// What a personal QR code carries, and how a scan reads one back.
///
/// The payload is a handle and nothing else. Not a user id: an id is a UUID
/// nobody can read aloud, it cannot be changed if the code ends up somewhere
/// public, and it would resolve for anyone who ever saw it. A handle is
/// already the public name of the account, its owner can drop or change it,
/// and the same string works typed into people search when a camera will not
/// focus.
///
/// Same scheme as the sign-in and device-link codes (`ababilx://…`), so one
/// scanner can tell the three apart by their host.
const String userQrHost = 'user';

String buildUserQrPayload(String username) =>
    'ababilx://$userQrHost?u=${Uri.encodeComponent(normalizeUsername(username))}';

/// The link a person shares instead of holding up the code. An https address
/// rather than the `ababilx://` payload: pasted into any chat it is tappable,
/// opens the app where it is installed (App Link) and a page offering it where
/// it is not.
const String userLinkHost = 'www.ababilx.com';

String buildUserLink(String username) =>
    'https://$userLinkHost/u/${Uri.encodeComponent(normalizeUsername(username))}';

/// A shared person link (DM details' Share) carries whatever that person lets
/// strangers find them by: their handle, or else their email. An email has
/// an `@` inside, so it cannot be mistaken for a handle. A `/u/+number` link
/// is not read: phone search is paused on mobile.
final RegExp _emailShape = RegExp(r'^[^\s@/]+@[^\s@/]+\.[^\s@/]+$');

bool isEmailRef(String value) => _emailShape.hasMatch(value);

/// The link for a shared person: a handle is normalised, an email goes in as
/// it is.
String buildContactLink(String value) {
  final v = value.trim();
  if (isEmailRef(v.toLowerCase())) {
    return 'https://$userLinkHost/u/${Uri.encodeComponent(v.toLowerCase())}';
  }
  return buildUserLink(v);
}

/// The handle (or, from a shared link, the email) inside a
/// scanned code, or null when this is not one of ours.
///
/// A bare `@handle` is accepted as well — printed on a poster or a business
/// card, that is what a person would encode, and the `@` is what makes the
/// intent explicit. Bare text with no `@` is deliberately NOT accepted: every
/// QR code in the world would otherwise look like a contact.
String? usernameFromQrPayload(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;

  if (text.startsWith('@')) return _valid(text);

  final uri = Uri.tryParse(text);
  if (uri == null) return null;
  if (_isUserLink(uri)) return _valid(uri.pathSegments[1]);
  if (uri.scheme != 'ababilx' || uri.host != userQrHost) return null;
  final handle = uri.queryParameters['u'] ?? '';
  return _valid(handle);
}

/// `https://www.ababilx.com/u/<handle>` — a shared link turned into a QR
/// code, or pasted where a code was expected.
bool _isUserLink(Uri uri) =>
    uri.scheme == 'https' &&
    (uri.host == userLinkHost || uri.host == 'ababilx.com') &&
    uri.pathSegments.length == 2 &&
    uri.pathSegments.first == 'u';

bool isUserQrPayload(String raw) => usernameFromQrPayload(raw) != null;

/// The scanned handle only has to be shaped like one — the server decides
/// whether it exists. Checking here keeps a mistyped or hostile code from
/// becoming a request URL.
String? _valid(String handle) {
  final ref = handle.trim().toLowerCase();
  if (isEmailRef(ref)) return ref;
  if (!isValidUsername(handle)) return null;
  return normalizeUsername(handle);
}
