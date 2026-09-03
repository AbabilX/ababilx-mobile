/// Matching people by name, when the name is decorated.
///
/// Every people list here filtered with `name.toLowerCase().contains(query)`.
/// That works for `Murad Hossain` and fails for every name someone has dressed
/// up: `⋆·˚ ୨♡୧ Murad ୨♡୧ ˚·⋆`, `𝕄𝕦𝕣𝕒𝕕`, `Ｍｕｒａｄ`, `M̶u̶r̶a̶d̶`. Typing `murad`
/// found none of them, so the person was simply absent from the list.
///
/// Folding both sides fixes it: strip the decoration, fold styled letterforms
/// back to ASCII, drop combining marks, and compare what is left. The filter is
/// deliberately one-directional — the *stored* name keeps every character it
/// was given, and only the comparison is normalised.
///
/// Pure and tested — `test/shared/name_search_test.dart`.
library;

import 'display_name.dart';
import 'styled_latin.dart';

/// Only the script-neutral marks are dropped: Latin diacritics, the overlay
/// strokes that make `M̶u̶r̶a̶d̶`, and the Zalgo ranges. A script's *own* marks
/// stay — Bengali vowel signs, the Arabic harakat and Devanagari matras are
/// letters as far as a reader is concerned, and folding them away would make
/// two different Bengali names collide.
final RegExp _mark = RegExp(
  '[\\u0300-\\u036F\\u1AB0-\\u1AFF\\u1DC0-\\u1DFF'
  '\\u20D0-\\u20F0\\uFE20-\\uFE2F]',
);

/// Letters, digits, and the script marks that survived [_mark] — a Bengali
/// vowel sign is `Mc`, not `L`, so keeping only letters would strip it.
final RegExp _keep = RegExp(r'[\p{L}\p{N}\p{M}]', unicode: true);
final RegExp _spaceRun = RegExp(r'\s+');

/// Normalises a name (or a query) into the form both sides are compared in:
/// lowercase, styled letterforms folded to ASCII, combining marks and
/// decoration removed, whitespace collapsed.
///
/// Non-Latin scripts pass through untouched — `জীবন` folds to `জীবন`, minus its
/// stars and hearts — because there is nothing to fold them *to*.
String foldNameForSearch(String? raw) {
  final cleaned = safeDisplayName(raw, fallback: '');
  if (cleaned.isEmpty) return '';
  final out = StringBuffer();
  for (final rune in cleaned.runes) {
    final folded = foldStyledCodePoint(rune);
    final ch = String.fromCharCode(folded ?? rune);
    if (_mark.hasMatch(ch)) continue;
    if (_keep.hasMatch(ch)) {
      out.write(ch.toLowerCase());
    } else if (ch.trim().isEmpty) {
      out.write(' ');
    }
    // Everything else — stars, hearts, dots, brackets — is decoration and is
    // dropped, so it can sit anywhere in a name without hiding it.
  }
  return out.toString().replaceAll(_spaceRun, ' ').trim();
}

/// True when [query] matches any of [fields].
///
/// An empty query matches everything, which is what a list filter wants before
/// the user has typed. Both sides go through [foldNameForSearch], so a decorated
/// name is found by its plain letters and a decorated *query* still finds a
/// plain name.
bool matchesNameQuery(String query, Iterable<String?> fields) {
  final needle = foldNameForSearch(query);
  if (needle.isEmpty) return true;
  for (final field in fields) {
    if (foldNameForSearch(field).contains(needle)) return true;
  }
  return false;
}
