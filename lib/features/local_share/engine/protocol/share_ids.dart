import 'dart:math';

final _idPattern = RegExp(r'^[A-Za-z0-9_-]{8,64}$');
const _hex = '0123456789abcdef';

/// Whether [value] may be used as a device, message or file id. Ids become
/// folder names on disk, so anything outside this alphabet is refused before
/// it reaches a path.
bool isShareId(Object? value) => value is String && _idPattern.hasMatch(value);

String _randomHex(int bytes) {
  final rand = Random.secure();
  final out = StringBuffer();
  for (var i = 0; i < bytes; i++) {
    final b = rand.nextInt(256);
    out
      ..write(_hex[b >> 4])
      ..write(_hex[b & 15]);
  }
  return out.toString();
}

/// A message or file id: 128 random bits.
String newShareId() => _randomHex(16);

/// The secret both devices keep after Accept: 256 random bits.
String newPairToken() => _randomHex(32);

/// Compares two secrets without stopping at the first different character.
bool sameSecret(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}
