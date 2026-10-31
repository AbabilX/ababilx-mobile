/// The invite code out of what someone pasted: the full link
/// (`https://www.ababilx.com/s/<code>`, scheme and www optional) or a bare
/// code. Only our own host counts; a code is 4–64 letters, digits, `-`, `_`.
String? parseInviteCode(String input) {
  var s = input.trim();
  if (s.isEmpty) return null;
  final code = RegExp(r'^[A-Za-z0-9_-]{4,64}$');
  if (code.hasMatch(s)) return s;
  if (!s.contains('://')) s = 'https://$s';
  final uri = Uri.tryParse(s);
  if (uri == null) return null;
  final host = uri.host.toLowerCase();
  if (host != 'ababilx.com' && host != 'www.ababilx.com') return null;
  final parts = uri.pathSegments.where((p) => p.isNotEmpty).toList();
  if (parts.length != 2 || parts[0] != 's') return null;
  return code.hasMatch(parts[1]) ? parts[1] : null;
}
