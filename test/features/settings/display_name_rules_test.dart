import 'package:flutter_test/flutter_test.dart';

import 'package:ababilx/features/settings/display-name/display_name_rules.dart';

/// Mirrors `TestNormalizeDisplayName` in
/// `ababilx-server/handlers/me/display_name_test.go`. If a case here starts
/// disagreeing with the Go one, the client is lying to the user about what
/// will actually be stored.
///
/// Every invisible character is written as an escape on purpose: a literal
/// U+202E in this file would reorder the source itself in most editors.
void main() {
  group('normalizeDisplayName', () {
    test('trims and collapses whitespace runs', () {
      expect(normalizeDisplayName('   Murad    Hossain  '), 'Murad Hossain');
    });

    test('newlines and tabs become a single space', () {
      expect(normalizeDisplayName('Murad\n\tHossain'), 'Murad Hossain');
    });

    test('drops a control char without splitting the word', () {
      expect(normalizeDisplayName('Mu\u0000rad'), 'Murad');
    });

    test('strips the direction-flipping controls used to spoof a name', () {
      expect(normalizeDisplayName('Murad\u202EHossain'), 'MuradHossain');
    });

    test('keeps ZWJ so emoji sequences survive', () {
      const family = '\u{1F468}\u200D\u{1F469}\u200D\u{1F467}';
      expect(normalizeDisplayName(family), family);
    });

    test('keeps ZWNJ, a real shaping character in Bengali', () {
      const zwnj = '\u0986\u200C\u0995';
      expect(normalizeDisplayName(zwnj), zwnj);
    });
  });

  group('isValidDisplayName', () {
    test('rejects empty and whitespace-only', () {
      expect(isValidDisplayName(''), isFalse);
      expect(isValidDisplayName('   \n\t '), isFalse);
    });

    test('rejects a name made only of invisibles', () {
      expect(isValidDisplayName('\u200B\u202E'), isFalse);
    });

    test('accepts exactly the cap and rejects one over', () {
      final at = '\u0986' * displayNameMaxRunes;
      expect(isValidDisplayName(at), isTrue);
      expect(isValidDisplayName('$at\u0986'), isFalse);
    });

    test('counts runes, not UTF-16 units, so emoji are not double-charged', () {
      final emoji = '\u{1F680}' * displayNameMaxRunes;
      expect(emoji.length, displayNameMaxRunes * 2);
      expect(isValidDisplayName(emoji), isTrue);
    });
  });

  test('displayNameRunesLeft floors at zero', () {
    expect(displayNameRunesLeft('Murad'), displayNameMaxRunes - 5);
    expect(displayNameRunesLeft('a' * (displayNameMaxRunes + 10)), 0);
  });
}
