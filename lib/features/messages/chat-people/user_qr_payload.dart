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

/// The handle inside a scanned code, or null when this is not one of ours.
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
  if (uri == null || uri.scheme != 'ababilx' || uri.host != userQrHost) {
    return null;
  }
  final handle = uri.queryParameters['u'] ?? '';
  return _valid(handle);
}

bool isUserQrPayload(String raw) => usernameFromQrPayload(raw) != null;

/// The scanned handle only has to be shaped like one — the server decides
/// whether it exists. Checking here keeps a mistyped or hostile code from
/// becoming a request URL.
String? _valid(String handle) {
  if (!isValidUsername(handle)) return null;
  return normalizeUsername(handle);
}
