import 'dart:convert';

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

/// TipTap/ProseMirror JSON → plain text (mirrors web `tiptapToPlainText`).
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
        .replaceAll(RegExp(r'\s+'), ' ')
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
