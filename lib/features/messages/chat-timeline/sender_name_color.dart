import 'package:flutter/painting.dart';

/// Signal gives every member of a group a stable name colour, so a run of
/// messages is attributable at a glance without reading the name each time.
/// The assignment is per-recipient and deterministic — the same person is the
/// same colour on every device — so it hangs off the user id, not list order.
///
/// The palette follows Signal's own name-colour set in spirit: saturated
/// enough to read on both themes, none of them the outgoing-bubble accent.
const _senderNamePalette = <Color>[
  Color(0xFF3B7DDD), // blue
  Color(0xFF2B9E6B), // green
  Color(0xFFC0562F), // burnt orange
  Color(0xFF8B5CD6), // violet
  Color(0xFF1E8E9E), // teal
  Color(0xFFC13C67), // rose
  Color(0xFF9A7B22), // ochre
  Color(0xFF5D6BC4), // indigo
  Color(0xFF2F8F8F), // cyan
  Color(0xFFB0504F), // brick
];

/// Stable per-user colour for a group sender name.
///
/// Uses the raw code units rather than [Object.hashCode], which Dart is free
/// to vary between runs — the colour has to survive a restart.
Color senderNameColor(String userId) {
  if (userId.isEmpty) return _senderNamePalette.first;
  var hash = 0;
  for (final unit in userId.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return _senderNamePalette[hash % _senderNamePalette.length];
}
