import 'dart:convert';

import '../data/models/wall_models.dart';

/// Builds TipTap JSON with `mention` + optional `wallCategory` nodes (web parity).
String encodeWallBody({
  required String plain,
  required Map<String, String> mentionByLabel,
  WallCategory? category,
}) {
  final text = plain.trim();
  if (text.isEmpty) {
    return jsonEncode({
      'type': 'doc',
      'content': [
        {
          'type': 'paragraph',
          'content': [
            {'type': 'text', 'text': ' '},
          ],
        },
      ],
    });
  }

  final labels = mentionByLabel.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  final catLabel = category?.label;
  final nodes = <Map<String, dynamic>>[];
  final buf = StringBuffer();
  var i = 0;

  void flush() {
    if (buf.isEmpty) return;
    nodes.add({'type': 'text', 'text': buf.toString()});
    buf.clear();
  }

  while (i < text.length) {
    var matched = false;
    if (text[i] == '@') {
      for (final label in labels) {
        final token = '@$label';
        if (text.startsWith(token, i) && _tokenEnd(text, i + token.length)) {
          flush();
          nodes.add({
            'type': 'mention',
            'attrs': {'id': mentionByLabel[label], 'label': label},
          });
          i += token.length;
          matched = true;
          break;
        }
      }
    } else if (catLabel != null && text.startsWith('#$catLabel', i)) {
      final token = '#$catLabel';
      if (_tokenEnd(text, i + token.length)) {
        flush();
        nodes.add({
          'type': 'wallCategory',
          'attrs': {'id': category!.slug, 'label': catLabel},
        });
        i += token.length;
        matched = true;
      }
    }
    if (!matched) {
      buf.write(text[i]);
      i++;
    }
  }
  flush();

  return jsonEncode({
    'type': 'doc',
    'content': [
      {'type': 'paragraph', if (nodes.isNotEmpty) 'content': nodes},
    ],
  });
}

bool _tokenEnd(String text, int idx) {
  if (idx >= text.length) return true;
  final c = text[idx];
  return c == ' ' || c == '\n' || c == ',' || c == '.' || c == '!';
}
