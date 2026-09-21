import 'dart:convert';

import 'markdown/message_markdown_preview.dart';

/// True when body is empty / empty TipTap doc (web `isTiptapEmpty`).
bool isTiptapEmpty(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return true;
  if (!_looksLikeTiptapJson(trimmed)) return false;
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is! Map) return false;
    final map = Map<String, dynamic>.from(decoded);
    if (map['type'] != 'doc') return false;
    final content = map['content'];
    if (content is! List || content.isEmpty) return true;
    return content.every((block) {
      if (block is! Map) return false;
      final b = Map<String, dynamic>.from(block);
      if (b['type'] != 'paragraph') return false;
      final inner = b['content'];
      return inner == null || (inner is List && inner.isEmpty);
    });
  } catch (_) {
    return false;
  }
}

/// Single-line form for sidebar rows, search hits and reply banners, where a
/// multi-line body has to fit one line. Never use it for a message body — that
/// is what flattened every paragraph into one run-on line.
/// Markdown syntax is stripped first, since a preview line cannot render it.
String tiptapToPreviewText(String? value) =>
    markdownToPreviewText(tiptapToPlainText(value))
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

/// Display labels of every `mention` node, longest first.
///
/// The chat-list preview flattens TipTap to plain `@Label` text, then has to
/// re-colour those tokens. A character-class regex stops at the first space,
/// so a name like "John Doe" only paints `@John`. Matching the labels TipTap
/// already stored — longest first, same order as [encodeTiptapBody] — keeps
/// the whole chip one colour without guessing where a name ends.
List<String> tiptapMentionLabels(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty || !_looksLikeTiptapJson(trimmed)) return const [];
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is! Map) return _mentionLabelsFromBroken(trimmed);
    final labels = <String>[];
    _collectMentionLabels(Map<String, dynamic>.from(decoded), labels);
    if (labels.isEmpty) return _mentionLabelsFromBroken(trimmed);
    labels.sort((a, b) => b.length.compareTo(a.length));
    return labels;
  } catch (_) {
    return _mentionLabelsFromBroken(trimmed);
  }
}

void _collectMentionLabels(Map<String, dynamic> node, List<String> out) {
  if (node['type'] == 'mention') {
    final attrs = node['attrs'];
    if (attrs is Map) {
      final label = (attrs['label'] ?? '').toString().trim();
      if (label.isNotEmpty && !out.contains(label)) out.add(label);
    }
  }
  final content = node['content'];
  if (content is! List) return;
  for (final child in content) {
    if (child is Map) {
      _collectMentionLabels(Map<String, dynamic>.from(child), out);
    }
  }
}

/// Sidebar truncates TipTap JSON; harvest every `"label"` that survives.
List<String> _mentionLabelsFromBroken(String body) {
  final labels = <String>[];
  final re = RegExp(r'"label"\s*:\s*"((?:\\.|[^"\\])*)"');
  for (final match in re.allMatches(body)) {
    final raw = match.group(1) ?? '';
    String label;
    try {
      label = jsonDecode('"$raw"') as String;
    } catch (_) {
      label = raw;
    }
    label = label.trim();
    if (label.isNotEmpty && !labels.contains(label)) labels.add(label);
  }
  labels.sort((a, b) => b.length.compareTo(a.length));
  return labels;
}

/// TipTap/ProseMirror JSON → plain text (mirrors web `tiptapToPlainText`).
/// Paragraph breaks survive as newlines, exactly as on web.
String tiptapToPlainText(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return '';
  if (!_looksLikeTiptapJson(trimmed)) return trimmed;
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is! Map) return _recoverBroken(trimmed);
    final map = Map<String, dynamic>.from(decoded);
    if (map['type'] != 'doc') return _recoverBroken(trimmed);
    final content = map['content'];
    if (content is! List || content.isEmpty) return _recoverBroken(trimmed);
    final plain = content
        .map(_nodeToPlainText)
        .map((line) => line.trimRight())
        .where((line) => line.isNotEmpty)
        .join('\n')
        .trim();
    if (plain.isEmpty || _looksLikeTiptapJson(plain)) {
      return _recoverBroken(trimmed);
    }
    return plain;
  } catch (_) {
    return _recoverBroken(trimmed);
  }
}

bool _looksLikeTiptapJson(String value) {
  final t = value.trim();
  return t.startsWith('{') && t.contains('"type"');
}

/// API sidebar truncates body at 120 chars — recover `"text"` fields via regex.
String extractFromBrokenTiptapJson(String body) {
  final texts = <String>[];
  final textRe = RegExp(r'"text"\s*:\s*"((?:\\.|[^"\\])*)"');
  for (final match in textRe.allMatches(body)) {
    final raw = match.group(1) ?? '';
    try {
      final decoded = jsonDecode('"$raw"') as String;
      if (decoded.isNotEmpty) texts.add(decoded);
    } catch (_) {
      if (raw.isNotEmpty) texts.add(raw);
    }
  }
  if (texts.isNotEmpty) {
    return texts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }
  final mention = RegExp(r'"label"\s*:\s*"((?:\\.|[^"\\])*)"').firstMatch(body);
  if (mention != null) {
    final raw = mention.group(1) ?? '';
    try {
      return '@${jsonDecode('"$raw"')}';
    } catch (_) {
      return '@$raw';
    }
  }
  if (RegExp(r'"type"\s*:\s*"mention"').hasMatch(body)) return 'Mention';
  if (RegExp(r'"type"\s*:\s*"link"').hasMatch(body)) return 'Link';
  return '';
}

String _recoverBroken(String body) {
  // The API sidebar truncates body at 120 chars. If we still cannot recover
  // any text from the broken JSON fragment, return empty so the preview line
  // shows "No messages yet" rather than the misleading literal "Message".
  return extractFromBrokenTiptapJson(body);
}

String _nodeToPlainText(dynamic node) {
  if (node is! Map) return '';
  final map = Map<String, dynamic>.from(node);
  final type = map['type'] as String?;
  if (type == 'hardBreak') return '\n';
  if (type == 'mention') {
    final attrs = map['attrs'];
    if (attrs is Map) {
      final label = attrs['label'] ?? attrs['id'] ?? '';
      return '@$label';
    }
    return '@';
  }
  if (type == 'wallCategory') {
    final attrs = map['attrs'];
    if (attrs is Map) {
      final label = attrs['label'] ?? attrs['id'] ?? '';
      return '#$label';
    }
    return '#';
  }
  final text = map['text'];
  if (text is String) return text;
  final content = map['content'];
  if (content is! List || content.isEmpty) return '';
  return content.map(_nodeToPlainText).join();
}

/// TipTap doc JSON for a plain string (web `textToTiptapJson`).
String textToTiptapJson(String text) {
  return jsonEncode({
    'type': 'doc',
    'content': [
      {
        'type': 'paragraph',
        'content': [
          {'type': 'text', 'text': text},
        ],
      },
    ],
  });
}
