import 'dart:convert';

/// The scheme a mention travels under once a body is markdown:
/// `[@Ann](mention:<user id>)`. Never opened as a link — the renderer turns a
/// tap on it into the profile sheet.
const mentionLinkScheme = 'mention:';

/// A chat body as markdown source — every bubble is drawn by gpt_markdown.
///
/// Plain text is markdown already. A TipTap document (web, desktop, or a
/// phone message carrying a mention) is rewritten: its marks become `**`,
/// `*`, `~~`, `` ` `` and links, its blocks become headings, lists, quotes and
/// fences, and a mention becomes a link on [mentionLinkScheme] so it stays
/// tappable. Text inside a node is passed through unescaped on purpose:
/// markdown typed into a rich editor renders as markdown too.
///
/// Null for an empty body and for JSON that is not a TipTap document (the
/// kanban webhook marker); those keep the TipTap renderer's own handling.
String? markdownOfBody(String? body) {
  final trimmed = body?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  if (!trimmed.startsWith('{')) return trimmed;
  Object? decoded;
  try {
    decoded = jsonDecode(trimmed);
  } catch (_) {
    // Text that merely starts with a brace.
    return trimmed;
  }
  if (decoded is! Map || decoded['type'] != 'doc') return null;
  final out = _blocks(decoded['content'], '').join('\n').trim();
  return out.isEmpty ? null : out;
}

List<String> _blocks(Object? nodes, String indent) {
  final lines = <String>[];
  if (nodes is! List) return lines;
  for (final node in nodes) {
    if (node is! Map) continue;
    final content = node['content'];
    switch (node['type']) {
      case 'paragraph':
        lines.add(_indent(_inline(content), indent));
      case 'heading':
        final level = (_attr(node, 'level') as num?)?.toInt() ?? 1;
        lines.add('$indent${'#' * level.clamp(1, 6)} ${_inline(content)}');
      case 'bulletList':
        lines.addAll(_list(content, indent, (_, _) => '- '));
      case 'taskList':
        lines.addAll(
          _list(
            content,
            indent,
            (_, item) => _attr(item, 'checked') == true ? '- [x] ' : '- [ ] ',
          ),
        );
      case 'orderedList':
        final start = (_attr(node, 'start') as num?)?.toInt() ?? 1;
        lines.addAll(_list(content, indent, (i, _) => '${start + i}. '));
      case 'blockquote':
        lines.addAll(_blocks(content, '').map((line) => '$indent> $line'));
      case 'codeBlock':
        final language = _attr(node, 'language') as String? ?? '';
        lines
          ..add('$indent```$language')
          ..add(_indent(_rawText(content), indent))
          ..add('$indent```');
      case 'horizontalRule':
        lines.add('$indent---');
      default:
        // An unknown block still shows its words.
        lines.addAll(_blocks(content, indent));
        if (content is List && content.every(_isInline)) {
          lines.add(_indent(_inline(content), indent));
        }
    }
  }
  return lines;
}

bool _isInline(Object? node) =>
    node is Map &&
    const {'text', 'mention', 'hardBreak'}.contains(node['type']);

/// One list: each item's first block follows its marker, the rest (a nested
/// list, a second paragraph) hang under it, indented.
List<String> _list(
  Object? items,
  String indent,
  String Function(int index, Map item) marker,
) {
  final lines = <String>[];
  if (items is! List) return lines;
  var index = 0;
  for (final item in items) {
    if (item is! Map) continue;
    final body = _blocks(item['content'], '');
    final lead = '$indent${marker(index++, item)}';
    lines.add('$lead${body.isEmpty ? '' : body.first}');
    for (final rest in body.skip(1)) {
      lines.add('$indent  $rest');
    }
  }
  return lines;
}

String _inline(Object? nodes) {
  if (nodes is! List) return '';
  final out = StringBuffer();
  for (final node in nodes) {
    if (node is! Map) continue;
    switch (node['type']) {
      case 'text':
        out.write(_marked(node['text'] as String? ?? '', node['marks']));
      case 'hardBreak':
        out.write('\n');
      case 'mention':
        final id = '${_attr(node, 'id') ?? ''}';
        final label = '${_attr(node, 'label') ?? ''}'
            .replaceAll('[', '(')
            .replaceAll(']', ')');
        out.write(
          id.isEmpty
              ? '@$label'
              : '[@$label]($mentionLinkScheme${Uri.encodeComponent(id)})',
        );
      case 'wallCategory':
        out.write('#${_attr(node, 'label') ?? ''}');
      default:
        out.write(_inline(node['content']));
    }
  }
  return out.toString();
}

/// Emphasis markers must hug the words, so the run's own edge spaces stay
/// outside them.
String _marked(String text, Object? marks) {
  if (marks is! List || marks.isEmpty || text.trim().isEmpty) return text;
  final types = <String, Map>{
    for (final mark in marks)
      if (mark is Map) '${mark['type']}': mark,
  };
  final lead = text.substring(0, text.length - text.trimLeft().length);
  final tail = text.substring(text.trimRight().length);
  var core = text.trim();
  if (types.containsKey('code')) {
    core = '`$core`';
  } else {
    if (types.containsKey('underline')) core = '<u>$core</u>';
    if (types.containsKey('strike')) core = '~~$core~~';
    if (types.containsKey('italic')) core = '*$core*';
    if (types.containsKey('bold')) core = '**$core**';
  }
  final href = '${_attr(types['link'], 'href') ?? ''}'.trim();
  if (href.isNotEmpty) core = '[$core](${href.replaceAll(' ', '%20')})';
  return '$lead$core$tail';
}

String _rawText(Object? nodes) {
  if (nodes is! List) return '';
  return nodes
      .whereType<Map>()
      .map((node) => node['text'] as String? ?? '')
      .join();
}

Object? _attr(Map? node, String key) {
  final attrs = node?['attrs'];
  return attrs is Map ? attrs[key] : null;
}

String _indent(String text, String indent) =>
    indent.isEmpty ? text : text.split('\n').map((l) => '$indent$l').join('\n');
