import 'mention_boundary.dart';

/// A URL, email or @mention run inside a chat-list preview line.
class PreviewHighlight {
  const PreviewHighlight({
    required this.start,
    required this.end,
    required this.isUrl,
  });

  final int start;
  final int end;
  final bool isUrl;

  bool get isMention => !isUrl;
}

const _email = r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(?:\.[A-Za-z0-9\-]+)+';

// Fallback for plain-text `@Name` with no TipTap label to match. A name keeps
// ONE script: a Latin first word takes further Capitalised Latin words, a
// Bengali one further Bengali words. Mixing them let "@all আজকে থেকে …" paint
// four words of the sentence as the name.
const _latinName = r'@[A-Za-z0-9_\-]+(?:\s+[A-Z][A-Za-z0-9_\-]*){0,3}';
const _bengaliName = r'@[ঀ-৿]+(?:\s+[ঀ-৿]+){0,2}';

/// Finds URL and @mention ranges in flattened preview text.
///
/// When [mentionLabels] comes from TipTap (via [tiptapMentionLabels]), each
/// `@Label` is matched exactly — including spaces inside a display name.
/// `@all` is always matched on its own: it is plain text on the wire, and it
/// never takes the words after it. Other `@` runs with no label fall back to
/// a short same-script guess so legacy plain text still paints `@First Last`.
List<PreviewHighlight> findPreviewHighlights(
  String text, {
  List<String> mentionLabels = const [],
}) {
  if (text.isEmpty) return const [];

  // The preview collapses whitespace, so a label must too or it never matches
  // and the fallback paints only the first word.
  final labels = {
    for (final label in mentionLabels)
      if (label.trim().isNotEmpty) label.trim().replaceAll(RegExp(r'\s+'), ' '),
  }.toList()..sort((a, b) => b.length.compareTo(a.length));

  final exact = [
    for (final l in labels) '@${RegExp.escape(l)}',
    '@$mentionAllLabel',
  ].join('|');
  final mentionAlt = labels.isEmpty
      ? '(?:$exact)$mentionEndLookahead|$_bengaliName|$_latinName'
      : '(?:$exact)$mentionEndLookahead';

  // An email is one link-coloured run. Checked before mentions, and a mention
  // must not follow a word character, or "me@gmail.com" painted "@gmail" as a
  // mention chip between two plain halves.
  final pattern = RegExp(
    'https?://[^\\s]+|$_email|(?<![A-Za-z0-9_.+\\-])(?:$mentionAlt)',
    unicode: true,
  );
  return [
    for (final match in pattern.allMatches(text))
      PreviewHighlight(
        start: match.start,
        end: match.end,
        isUrl: !match.group(0)!.startsWith('@'),
      ),
  ];
}
