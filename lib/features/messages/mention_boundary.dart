/// Where an `@Label` mention ends — one rule for the composer's chip, the
/// TipTap encoder and the chat-list preview, so all three agree.
///
/// A mention ends at anything that cannot continue a word: space, newline,
/// any punctuation (`?`, `:`, `)`, the Bengali danda `।`), an emoji. Only a
/// letter, combining mark, digit or `_` continues it, so "@Jo" never matches
/// inside "@Joanne" and "@রহিমের" is not "@রহিম". The old rule accepted only
/// space `,` `.` `!`, so "@Murad Ahmed?" was sent as plain text and every
/// reader drew half a name.
final mentionWordChar = RegExp(r'[\p{L}\p{M}\p{N}_]', unicode: true);

/// Regex lookahead for [mentionEndsAt], for building patterns.
const mentionEndLookahead = r'(?![\p{L}\p{M}\p{N}_])';

/// True when a mention token ending at [idx] in [text] ends a word there.
bool mentionEndsAt(String text, int idx) {
  if (idx >= text.length) return true;
  // A surrogate pair (emoji) is never a word character.
  return !mentionWordChar.hasMatch(text[idx]);
}

/// `@all` is plain text on the wire — no mention node — so every renderer
/// recognises it by name, and it never grows into the words after it.
const mentionAllLabel = 'all';
