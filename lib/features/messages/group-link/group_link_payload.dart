import '../../settings/username/username_rules.dart';
import '../chat-people/user_qr_payload.dart';

/// A group's public link, and how a tapped or scanned one is read back.
///
/// The slug follows the handle rules (server `0167` reuses them), so the same
/// check serves both. `https://www.ababilx.com/g/<slug>` is what gets shared;
/// `ababilx://group?g=<slug>` is what the site's button fires.
const String groupLinkHost = 'group';

String buildGroupLink(String slug) =>
    'https://$userLinkHost/g/${Uri.encodeComponent(normalizeUsername(slug))}';

/// What the admin sheet shows in front of the field.
const String groupLinkPrefix = 'ababilx.com/g/';

/// The slug inside a link, or null when this is not a group link of ours.
String? slugFromGroupLink(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null) return null;
  String? slug;
  if (uri.scheme == 'https' &&
      (uri.host == userLinkHost || uri.host == 'ababilx.com') &&
      uri.pathSegments.length == 2 &&
      uri.pathSegments.first == 'g') {
    slug = uri.pathSegments[1];
  } else if (uri.scheme == 'ababilx' && uri.host == groupLinkHost) {
    slug = uri.queryParameters['g'];
  }
  if (slug == null || !isValidUsername(slug)) return null;
  return normalizeUsername(slug);
}
