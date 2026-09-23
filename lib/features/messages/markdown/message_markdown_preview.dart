import 'message_markdown_source.dart';

/// Markdown as the words a reader sees, for one-line surfaces: the chat-list
/// row, notifications, reply banners, quotes and search hits.
///
/// The bubble renders markdown; a preview line cannot, so it showed the raw
/// `**`, `#` and `|` instead. Stripping here keeps every single-line surface
/// agreeing with the bubble. Text that does not look like markdown is returned
/// unchanged, so an ordinary `2 * 3` keeps its asterisk.
///
/// Newlines are kept: callers collapse whitespace themselves, and the block
/// rules below need to see line starts.
String markdownToPreviewText(String text) {
  if (!looksLikeMarkdown(text)) return text;
  final out = <String>[];
  var fenced = false;
  for (final raw in text.split('\n')) {
    if (_fence.hasMatch(raw)) {
      fenced = !fenced;
      continue;
    }
    if (fenced) {
      out.add(raw);
      continue;
    }
    if (_rule.hasMatch(raw) || _tableDivider.hasMatch(raw)) continue;
    var line = raw
        .replaceFirst(_heading, '')
        .replaceFirst(_quote, '')
        .replaceFirst(_task, '')
        .replaceFirst(_bullet, '');
    if (_tableRow.hasMatch(line)) {
      line = line
          .trim()
          .replaceAll(RegExp(r'^\||\|$'), '')
          .split('|')
          .map((cell) => cell.trim())
          .where((cell) => cell.isNotEmpty)
          .join(' · ');
    }
    out.add(_stripInline(line));
  }
  return out.join('\n');
}

String _stripInline(String line) => line
    .replaceAllMapped(_image, (m) => m[1]!)
    .replaceAllMapped(_link, (m) => m[1]!)
    .replaceAllMapped(_code, (m) => m[1]!)
    .replaceAllMapped(_strongStar, (m) => m[1]!)
    .replaceAllMapped(_strongUnderscore, (m) => m[1]!)
    .replaceAllMapped(_strike, (m) => m[1]!)
    .replaceAllMapped(_emStar, (m) => '${m[1]}${m[2]}')
    .replaceAllMapped(_emUnderscore, (m) => '${m[1]}${m[2]}');

final _fence = RegExp(r'^[ \t]{0,3}(```|~~~)');
final _rule = RegExp(r'^[ \t]{0,3}(?:[-*_][ \t]*){3,}$');
final _tableDivider = RegExp(
  r'^[ \t]*\|?[ \t]*:?-{3,}:?[ \t]*(\|[ \t]*:?-{3,}:?[ \t]*)*\|?[ \t]*$',
);
final _tableRow = RegExp(r'^[ \t]*\|.*\|[ \t]*$');
final _heading = RegExp(r'^[ \t]{0,3}#{1,6}[ \t]+');
final _quote = RegExp(r'^[ \t]{0,3}(?:>[ \t]?)+');
final _task = RegExp(r'^[ \t]*[-*+][ \t]+\[[ xX]\][ \t]+');
final _bullet = RegExp(r'^[ \t]*[-*+][ \t]+(?=\S)');
final _image = RegExp(r'!\[([^\]\n]*)\]\([^)\s]+\)');
final _link = RegExp(r'\[([^\]\n]+)\]\([^)\s]+\)');
final _code = RegExp(r'`([^`\n]+)`');
final _strongStar = RegExp(r'\*\*([^*\s](?:[^*]*[^*\s])?)\*\*');
final _strongUnderscore = RegExp(r'__([^_\s](?:[^_]*[^_\s])?)__');
final _strike = RegExp(r'~~([^~\s](?:[^~]*[^~\s])?)~~');
final _emStar = RegExp(r'(^|[^\w*])\*([^*\s](?:[^*\n]*[^*\s])?)\*(?!\w)');
final _emUnderscore = RegExp(r'(^|[^\w_])_([^_\s](?:[^_\n]*[^_\s])?)_(?!\w)');
