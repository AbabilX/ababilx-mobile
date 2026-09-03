/// Folds decorative Latin letterforms back to plain ASCII.
///
/// Unicode carries a dozen full alphabets that look like styled Latin but share
/// no code point with it — 𝕄𝕦𝕣𝕒𝕕, 𝐌𝐮𝐫𝐚𝐝, 𝓜𝓾𝓻𝓪𝓭, Ｍｕｒａｄ, ⓂⓊⓇⒶⒹ. To a
/// `contains` search they are unrelated strings, so a person who styles their
/// name that way becomes unfindable by typing it: they vanish from every people
/// list even though the row is right there.
///
/// Pure and tested — `test/shared/name_search_test.dart`.
library;

/// The 26-letter runs of the Mathematical Alphanumeric Symbols block, as
/// `start → ASCII base`. Each run is contiguous; the handful of reserved slots
/// inside them are unassigned, so no real name contains one.
const Map<int, int> _letterRuns = {
  0x1D400: 0x41, 0x1D41A: 0x61, // bold
  0x1D434: 0x41, 0x1D44E: 0x61, // italic
  0x1D468: 0x41, 0x1D482: 0x61, // bold italic
  0x1D49C: 0x41, 0x1D4B6: 0x61, // script
  0x1D4D0: 0x41, 0x1D4EA: 0x61, // bold script
  0x1D504: 0x41, 0x1D51E: 0x61, // fraktur
  0x1D538: 0x41, 0x1D552: 0x61, // double-struck
  0x1D56C: 0x41, 0x1D586: 0x61, // bold fraktur
  0x1D5A0: 0x41, 0x1D5BA: 0x61, // sans-serif
  0x1D5D4: 0x41, 0x1D5EE: 0x61, // sans-serif bold
  0x1D608: 0x41, 0x1D622: 0x61, // sans-serif italic
  0x1D63C: 0x41, 0x1D656: 0x61, // sans-serif bold italic
  0x1D670: 0x41, 0x1D68A: 0x61, // monospace
  0xFF21: 0x41, 0xFF41: 0x61, // fullwidth
  0x24B6: 0x41, 0x24D0: 0x61, // circled
};

/// Ten-digit runs, same shape.
const Map<int, int> _digitRuns = {
  0x1D7CE: 0x30,
  0x1D7D8: 0x30,
  0x1D7E2: 0x30,
  0x1D7EC: 0x30,
  0x1D7F6: 0x30,
  0xFF10: 0x30,
};

/// The letters the Mathematical Alphanumeric block leaves as holes, because
/// their glyphs already existed in Letterlike Symbols.
const Map<int, int> _letterlike = {
  0x210A: 0x67,
  0x210B: 0x48,
  0x210C: 0x48,
  0x210D: 0x48,
  0x210E: 0x68,
  0x2110: 0x49,
  0x2111: 0x49,
  0x2112: 0x4C,
  0x2113: 0x6C,
  0x2115: 0x4E,
  0x2119: 0x50,
  0x211A: 0x51,
  0x211B: 0x52,
  0x211C: 0x52,
  0x211D: 0x52,
  0x2124: 0x5A,
  0x2128: 0x5A,
  0x212C: 0x42,
  0x212D: 0x43,
  0x212F: 0x65,
  0x2130: 0x45,
  0x2131: 0x46,
  0x2133: 0x4D,
  0x2134: 0x6F,
  0x2102: 0x43,
};

/// Latin letters carrying a diacritic, folded to their base. Dart has no
/// Unicode normalisation, so the common ranges are spelled out.
const String _accented =
    'ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝ'
    'àáâãäåæçèéêëìíîïðñòóôõöøùúûüýÿ'
    'ĀāĂăĄąĆćĈĉĊċČčĎďĐđĒēĔĕĖėĘęĚě'
    'ĜĝĞğĠġĢģĤĥĦħĨĩĪīĬĭĮįİıĴĵĶķĹĺĻļĽľŁłŃńŅņŇňŌōŎŏŐő'
    'ŔŕŖŗŘřŚśŜŝŞşŠšŢţŤťŦŧŨũŪūŬŭŮůŰűŲųŴŵŶŷŸŹźŻżŽž';
const String _plain =
    'AAAAAAACEEEEIIIIDNOOOOOOUUUUY'
    'aaaaaaaceeeeiiiidnoooooouuuuyy'
    'AaAaAaCcCcCcCcDdDdEeEeEeEeEe'
    'GgGgGgGgHhHhIiIiIiIiIiJjKkLlLlLlLlNnNnNnOoOoOo'
    'RrRrRrSsSsSsSsTtTtTtUuUuUuUuUuUuWwYyYZzZzZz';

/// The ASCII code point [cp] should fold to, or null when it is already plain
/// or has no Latin equivalent.
int? foldStyledCodePoint(int cp) {
  final letterlike = _letterlike[cp];
  if (letterlike != null) return letterlike;
  for (final entry in _letterRuns.entries) {
    final offset = cp - entry.key;
    if (offset >= 0 && offset < 26) return entry.value + offset;
  }
  for (final entry in _digitRuns.entries) {
    final offset = cp - entry.key;
    if (offset >= 0 && offset < 10) return entry.value + offset;
  }
  if (cp >= 0x2460 && cp <= 0x2468) return 0x31 + (cp - 0x2460); // ① … ⑨
  if (cp == 0x24EA) return 0x30; // ⓪
  final accented = _accented.indexOf(String.fromCharCode(cp));
  if (accented >= 0 && accented < _plain.length) {
    return _plain.codeUnitAt(accented);
  }
  return null;
}
