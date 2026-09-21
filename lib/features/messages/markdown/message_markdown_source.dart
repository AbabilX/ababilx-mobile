import 'dart:convert';

/// The markdown a chat body was written in, or null when it should keep the
/// TipTap renderer.
///
/// Bots, webhook feeds and people pasting from an AI assistant send markdown
/// as literal text: `**bold**`, `- item`, fenced code. TipTap stores that as
/// plain paragraphs, so without this the bubble showed the asterisks. Only a
/// body whose TipTap is *plain* (paragraphs of unmarked text and line breaks)
/// qualifies — a body with real marks, lists or mentions already carries its
/// formatting, and a mention has to stay a tappable chip.
///
/// The syntax check keeps ordinary messages on the existing renderer, so a
/// sentence that happens to contain one `*` is not reinterpreted.
///
/// Web twin: `components/team/board/tiptap/markdown-source.ts` in both web
/// trees. Same rule, same regexes — change both, or a message renders
/// formatted on one device and raw on the other.
String? markdownSourceOf(String? body) {
  final trimmed = body?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  final text = _plainTextOf(trimmed);
  if (text == null || !looksLikeMarkdown(text)) return null;
  return text;
}

/// True when [text] carries markdown syntax worth rendering.
bool looksLikeMarkdown(String text) =>
    _blockSyntax.hasMatch(text) || _inlineSyntax.hasMatch(text);

final _blockSyntax = RegExp(
  r'^[ \t]{0,3}(?:#{1,6}[ \t]+\S|[-*+][ \t]+\S|\d{1,3}[.)][ \t]+\S|>[ \t]?\S'
  r'|```|~~~|(?:[-*_][ \t]*){3,}$|\|.*\|[ \t]*$|- \[[ xX]\] )',
  multiLine: true,
);

final _inlineSyntax = RegExp(
  r'\*\*[^*\s](?:[^*]*[^*\s])?\*\*'
  r'|__[^_\s](?:[^_]*[^_\s])?__'
  r'|~~[^~\s](?:[^~]*[^~\s])?~~'
  r'|`[^`\n]+`'
  r'|\[[^\]\n]+\]\([^)\s]+\)',
);

/// The body as markdown source: plain text as it is, a plain TipTap doc as
/// its paragraphs joined by newlines. Null for rich TipTap.
String? _plainTextOf(String body) {
  if (!body.startsWith('{')) return body;
  // JSON that is not a TipTap doc (the kanban webhook marker, anything else)
  // is never re-read as markdown — web's `markdown-source.ts` agrees.
  if (!body.contains('"type"')) return null;
  Object? decoded;
  try {
    decoded = jsonDecode(body);
  } catch (_) {
    return null;
  }
  if (decoded is! Map || decoded['type'] != 'doc') return null;
  final blocks = decoded['content'];
  if (blocks is! List) return null;
  final lines = <String>[];
  for (final block in blocks) {
    if (block is! Map || block['type'] != 'paragraph') return null;
    final inline = block['content'];
    final line = StringBuffer();
    if (inline is List) {
      for (final node in inline) {
        if (node is! Map) return null;
        final marks = node['marks'];
        if (marks is List && marks.isNotEmpty) return null;
        switch (node['type']) {
          case 'text':
            line.write(node['text'] as String? ?? '');
          case 'hardBreak':
            line.write('\n');
          default:
            return null;
        }
      }
    }
    lines.add(line.toString());
  }
  return lines.join('\n').trim();
}
