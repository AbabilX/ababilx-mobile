/// Bengali block, U+0980–U+09FF.
final _bengali = RegExp('[ঀ-৿]');

/// Letter spacing that is safe for [text]: [value] for Latin, 0 as soon as
/// any Bengali is in it. Tracking is inserted between glyphs, and in Bengali
/// that pulls vowel signs and the nukta off their consonant (য়া -> "য় া").
/// Use it wherever a style sets its own letterSpacing on text that can be
/// translated or typed by a person.
double latinTracking(String text, double value) =>
    _bengali.hasMatch(text) ? 0 : value;
