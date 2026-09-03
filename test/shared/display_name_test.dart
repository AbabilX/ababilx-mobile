import 'package:ababilx/shared/text/display_name.dart';
import 'package:flutter_test/flutter_test.dart';

/// The name from the bug report: a lock, decorative stars and hearts, then the
/// Bengali the person actually goes by.
const decorated =
    '\u{1F512} ⋆·˚ ୨♡୧ '
    '˚·⋆ জীবন';

void main() {
  group('safeDisplayName', () {
    test('keeps a decorated name intact', () {
      expect(safeDisplayName(decorated), decorated);
    });

    test('falls back on null, blank and invisible-only names', () {
      expect(safeDisplayName(null), 'Unknown');
      expect(safeDisplayName('   '), 'Unknown');
      expect(safeDisplayName('\u200B\u202E\uFEFF'), 'Unknown');
      expect(safeDisplayName('', fallback: 'Direct message'), 'Direct message');
    });

    test('drops the bidi override that flips the rest of a row', () {
      expect(safeDisplayName('Murad\u202EHossain'), 'MuradHossain');
      expect(safeDisplayName('\u2066a\u2069b'), 'ab');
    });

    test('keeps ZWJ and ZWNJ — emoji and Bengali need them', () {
      const family = '\u{1F468}‍\u{1F469}‍\u{1F467}';
      expect(safeDisplayName(family), family);
      expect(safeDisplayName('র্‌য'), 'র্‌য');
    });

    test('collapses newlines and tabs so a name cannot span rows', () {
      expect(safeDisplayName('Murad\nHossain'), 'Murad Hossain');
      expect(safeDisplayName(' Murad \t\n  Hossain '), 'Murad Hossain');
    });

    // The reported bug: a peer set a name built from blank glyphs, and their
    // row in the chat list had an avatar, a timestamp and a preview, but no
    // title at all — nothing to read, say or report.
    test('falls back on a name built from blank glyphs', () {
      for (final blank in [
        'ㅤ', // U+3164 Hangul filler
        'ㅤㅤㅤ',
        '⠀', // U+2800 Braille pattern blank
        'ᅟᅠ', // U+115F U+1160 Hangul choseong + jungseong fillers
        'ﾠ', // U+FFA0 halfwidth Hangul filler
        '឴឵', // U+17B4 U+17B5 Khmer inherent vowels
        '͏', // U+034F combining grapheme joiner
        ' ㅤ ⠀ ',
      ]) {
        expect(
          safeDisplayName(blank),
          'Unknown',
          reason: blank.codeUnits.toString(),
        );
        expect(displayNameInitial(blank), isNull);
      }
    });

    test('keeps a blank glyph that sits beside real text', () {
      expect(safeDisplayName('Muradㅤ Hossain'), 'Muradㅤ Hossain');
    });

    test('caps a Zalgo mark stack at two per base character', () {
      const zalgo = 'Ḿ̂̃̄̅̆urad';
      expect(safeDisplayName(zalgo), 'Ḿ̂urad');
    });

    test('bounds length and never ends on a dangling mark', () {
      final long = 'x' * 200;
      expect(safeDisplayName(long).runes.length, displayNameMaxRunes);
      final marked = '${'x' * (displayNameMaxRunes - 1)}ý';
      expect(safeDisplayName(marked).runes.last, isNot(0x0301));
    });
  });

  group('displayNameInitial', () {
    test('skips emoji and decoration to the first real letter', () {
      expect(displayNameInitial(decorated), 'জী');
      expect(displayNameInitial('\u{1F512} Murad'), 'M');
    });

    test('never returns half a surrogate pair', () {
      final initial = displayNameInitial('\u{1F512}\u{1F600}Murad')!;
      expect(initial, 'M');
      expect(initial.codeUnits.every((u) => u < 0xD800 || u > 0xDFFF), isTrue);
    });

    test(
      'is null when nothing readable is left, so the caller draws an icon',
      () {
        expect(displayNameInitial('\u{1F512}\u{1F600}'), isNull);
        expect(displayNameInitial('⋆·˚'), isNull);
        expect(displayNameInitial(null), isNull);
        expect(displayNameInitial(''), isNull);
      },
    );

    test('prefers a letter over a digit-shaped ornament', () {
      // ୨ and ୧ are Oriya digits used as a decorative bracket. Taking the
      // first letter-or-digit would show ୨ and hide who the row is.
      expect(displayNameInitial('୨♡୧ Murad ୨♡୧'), 'M');
      // A name with no letter at all still gets its digit.
      expect(displayNameInitial('007'), '0');
    });
  });
}
