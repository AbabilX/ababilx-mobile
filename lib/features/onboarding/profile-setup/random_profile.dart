import 'dart:math';

/// What profile setup fills in: a friendly two-word name and a handle built
/// from it plus four digits. The username step asks the server whether that
/// handle is free before it keeps the draw.
abstract final class RandomProfile {
  static const _adjectives = [
    'Calm',
    'Bright',
    'Swift',
    'Quiet',
    'Brave',
    'Clever',
    'Gentle',
    'Happy',
    'Lucky',
    'Sunny',
    'Misty',
    'Bold',
    'Kind',
    'Wild',
    'Cosmic',
    'Silver',
  ];
  static const _nouns = [
    'Falcon',
    'River',
    'Tiger',
    'Lotus',
    'Comet',
    'Maple',
    'Otter',
    'Panda',
    'Sparrow',
    'Willow',
    'Cedar',
    'Dolphin',
    'Ember',
    'Harbor',
    'Meadow',
    'Robin',
  ];

  static String name([Random? random]) {
    final r = random ?? Random.secure();
    return '${_adjectives[r.nextInt(_adjectives.length)]} '
        '${_nouns[r.nextInt(_nouns.length)]}';
  }

  /// `calm_falcon4821` from "Calm Falcon": lowercase ASCII, one separator,
  /// within the server's 3–32 rule, never a reserved word.
  static String username(String fromName, [Random? random]) {
    final r = random ?? Random.secure();
    var base = fromName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (base.length < 3) base = 'user';
    if (base.length > 26) {
      base = base.substring(0, 26).replaceAll(RegExp(r'_+$'), '');
    }
    return '$base${1000 + r.nextInt(9000)}';
  }
}
