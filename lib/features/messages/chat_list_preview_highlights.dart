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

/// Finds URL and @mention ranges in flattened preview text.
///
/// When [mentionLabels] comes from TipTap (via [tiptapMentionLabels]), each
/// `@Label` is matched exactly — including spaces inside a display name. Without
/// labels, a short multi-token fallback is used so legacy plain text still
/// paints `@First Last` instead of stopping at the first space.
List<PreviewHighlight> findPreviewHighlights(
  String text, {
  List<String> mentionLabels = const [],
}) {
  if (text.isEmpty) return const [];

  final labels = [
    for (final label in mentionLabels)
      if (label.trim().isNotEmpty) label.trim(),
  ]..sort((a, b) => b.length.compareTo(a.length));

  final mentionAlt = labels.isEmpty
      // Fallback only: continuation tokens look like name parts (Capitalised
      // Latin or Bengali), so "@John Doe hey" does not paint "hey".
      ? r'@[A-Za-z0-9_\-\u0980-\u09FF]+'
            r'(?:\s+(?:[A-Z][A-Za-z0-9_\-]*|[\u0980-\u09FF]+(?:\s+-\s+[\u0980-\u09FF]+)?)){0,4}'
      : labels.map((l) => '@${RegExp.escape(l)}').join('|');

  // An email is one link-coloured run. Checked before mentions, and a mention
  // must not follow a word character, or "me@gmail.com" painted "@gmail" as a
  // mention chip between two plain halves.
  final pattern = RegExp(
    'https?://[^\\s]+|$_email|(?<![A-Za-z0-9_.+\\-])(?:$mentionAlt)',
  );
  final out = <PreviewHighlight>[];
  for (final match in pattern.allMatches(text)) {
    final token = match.group(0)!;
    out.add(
      PreviewHighlight(
        start: match.start,
        end: match.end,
        isUrl: !token.startsWith('@'),
      ),
    );
  }
  return out;
}
