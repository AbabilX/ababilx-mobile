/// Display names are hostile input.
///
/// A name is whatever another account typed into their profile — decorative
/// symbols, stacked combining marks, direction-flipping controls, hundreds of
/// characters. `handlers/me.NormalizeDisplayName` cleans names set through our
/// own API, but a name copied from a GitHub or Google profile never passes
/// through it, and an older row predates the rule entirely. So the client
/// sanitises again at the point of rendering and treats the stored value as
/// untrusted every time.
///
/// Pure and tested — `test/shared/display_name_test.dart`. Change the rules
/// there, not inside a widget.
library;

/// What a person with no name is called. A "Start New Chat" account has no
/// name, email or username at all (2026-10-20), and a blank row reads as a
/// broken one.
const String namelessUserLabel = 'AbabilX user';

/// Rendering cap. Nothing legible lives past this, and it bounds the layout
/// cost of a name built to be pathological.
const int displayNameMaxRunes = 64;

/// How many combining marks may ride one base character. Two covers every real
/// script; the rest is Zalgo, which draws far outside its own line box.
const int _maxCombiningMarks = 2;

/// Invisible characters that render as nothing but change how the rest of the
/// name reads — bidi embeddings, overrides and isolates, zero-width space, the
/// word joiner, the BOM, and the line/paragraph separators.
///
/// U+200D (ZWJ) and U+200C (ZWNJ) deliberately survive: the first holds emoji
/// sequences together, the second is a real letter-shaping character in
/// Bengali, Persian and Arabic. The server keeps the same two, for the same
/// reason.
final RegExp _invisible = RegExp(
  '[\\u00AD\\u061C\\u200B\\u200E\\u200F\\u2028\\u2029'
  '\\u202A-\\u202E\\u2060-\\u2064\\u2066-\\u2069\\uFEFF]',
);

final RegExp _controls = RegExp(
  '[\\u0000-\\u0008\\u000B\\u000C\\u000E-\\u001F\\u007F-\\u009F]',
);

final RegExp _whitespaceRun = RegExp(r'\s+');

/// Combining marks, plus the joiners and variation selectors that must not be
/// left dangling at a truncation point.
final RegExp _mark = RegExp(r'\p{M}', unicode: true);
final RegExp _joiner = RegExp('[\\u200C\\u200D\\uFE00-\\uFE0F]');

/// Characters that occupy space but paint nothing. Unicode files them as
/// letters and symbols — U+3164 HANGUL FILLER is `Lo`, U+2800 BRAILLE PATTERN
/// BLANK is `So` — so every category check passes them and a name built from
/// them renders as an empty row. That is exactly why they get chosen.
final RegExp _blankGlyph = RegExp(
  '[\\u034F\\u115F\\u1160\\u17B4\\u17B5\\u180B-\\u180E'
  '\\u2800\\u3164\\uFE00-\\uFE0F\\uFFA0]',
);

/// Anything that actually draws.
final RegExp _visible = RegExp(r'[\p{L}\p{N}\p{P}\p{S}]', unicode: true);

final RegExp _letter = RegExp(r'\p{L}', unicode: true);
final RegExp _digit = RegExp(r'\p{N}', unicode: true);

/// Cleans a name for display and never returns an empty string.
///
/// Whitespace runs (newlines included) collapse to one space so a name cannot
/// smuggle line breaks into a list row; invisibles and controls are dropped;
/// mark stacks are capped; the result is bounded at [displayNameMaxRunes].
/// A name left with nothing renderable falls back rather than showing blank.
String safeDisplayName(String? raw, {String fallback = 'Unknown'}) {
  if (raw == null) return fallback;
  var name = raw.replaceAll(_invisible, '').replaceAll(_controls, '');
  name = name.replaceAll(_whitespaceRun, ' ').trim();
  name = _capCombiningMarks(name);
  name = _truncateRunes(name, displayNameMaxRunes);
  return _drawsSomething(name) ? name : fallback;
}

/// Whether a name paints at least one thing a reader can see.
///
/// A name made only of blank glyphs is the "invisible name" trick: the row
/// keeps its avatar, timestamp and preview, and the title is simply not there,
/// so nobody can read, say or report who it belongs to.
bool _drawsSomething(String name) {
  if (name.isEmpty) return false;
  return _visible.hasMatch(name.replaceAll(_blankGlyph, ''));
}

/// The avatar letter: the first grapheme that starts with a letter, with its
/// own marks attached, uppercased.
///
/// A **letter** is preferred over a digit anywhere in the name, and a digit is
/// only taken when the name holds no letter at all. Decorative names lean on
/// digit-shaped ornaments — the `୨♡୧` bracket is a pair of Oriya digits — so
/// first-letter-or-digit would pick the ornament over the name every time.
///
/// Returns null when a name carries nothing readable — an all-emoji handle, or
/// one made only of stars and hearts — so the caller draws its person icon
/// instead of a broken glyph. Taking `name[0]` instead splits a surrogate pair
/// and renders a tofu box for every name that opens with an emoji.
String? displayNameInitial(String? raw) {
  final name = safeDisplayName(raw, fallback: '');
  if (name.isEmpty) return null;
  return _graphemeAt(name, _letter) ?? _graphemeAt(name, _digit);
}

/// The first grapheme whose base character matches [base], marks included.
String? _graphemeAt(String name, RegExp base) {
  final runes = name.runes.toList();
  for (var i = 0; i < runes.length; i++) {
    final ch = String.fromCharCode(runes[i]);
    if (!base.hasMatch(ch)) continue;
    final buffer = StringBuffer(ch);
    for (var j = i + 1; j < runes.length; j++) {
      final next = String.fromCharCode(runes[j]);
      if (!_mark.hasMatch(next) && !_joiner.hasMatch(next)) break;
      buffer.write(next);
    }
    return buffer.toString().toUpperCase();
  }
  return null;
}

String _capCombiningMarks(String value) {
  final out = StringBuffer();
  var run = 0;
  for (final rune in value.runes) {
    final ch = String.fromCharCode(rune);
    if (_mark.hasMatch(ch)) {
      if (run >= _maxCombiningMarks) continue;
      run++;
    } else {
      run = 0;
    }
    out.write(ch);
  }
  return out.toString();
}

/// Cuts to [limit] runes, then walks back off any mark or joiner left hanging
/// at the new end — half an emoji sequence renders worse than a shorter name.
String _truncateRunes(String value, int limit) {
  final runes = value.runes.toList();
  if (runes.length <= limit) return value;
  var end = limit;
  while (end > 0) {
    final ch = String.fromCharCode(runes[end - 1]);
    if (!_mark.hasMatch(ch) && !_joiner.hasMatch(ch)) break;
    end--;
  }
  return String.fromCharCodes(runes.take(end)).trimRight();
}

/// How to name a person when a row carries both their display name and their
/// handle: the name, else "@username", else [namelessUserLabel]. A person may
/// remove their name (server migration 0185); chat read paths already fold
/// the handle in server-side, this covers rows that ship the two apart
/// (people search, connections, requests).
String personLabel(String? name, String? username) {
  final handle = username?.trim() ?? '';
  return safeDisplayName(
    name,
    fallback: handle.isEmpty ? namelessUserLabel : '@$handle',
  );
}
