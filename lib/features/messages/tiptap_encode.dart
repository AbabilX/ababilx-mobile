import 'dart:convert';

/// Turns a composer's plain text back into TipTap JSON, with real `mention`
/// (and optional `wallCategory`) nodes rather than one flat text run.
///
/// Every mobile composer is a plain [TextField]: picking someone from the
/// mention popover only inserts "@Their Name" into the string, and the user id
/// survives out of band. Encoding that string as a single text node loses the
/// mention entirely — web, desktop and mobile all key their chip off a
/// `mention` node, so a message written on a phone showed the name as ordinary
/// unstyled text everywhere it was read, and the server's
/// `ParseMentionIDsFromTiptap` found nothing to notify.
///
/// Labels are matched longest-first because one display name can be a prefix of
/// another ("Jo" and "Jo Anne"): the shorter one would otherwise win and leave
/// a stray " Anne" behind.
String encodeTiptapBody({
  required String plain,
  Map<String, String> mentionByLabel = const {},
  String? tagLabel,
  String? tagId,
}) {
  final text = plain.trim();
  if (text.isEmpty) return _doc(const []);

  final labels = mentionByLabel.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
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
    } else if (tagLabel != null && text.startsWith('#$tagLabel', i)) {
      final token = '#$tagLabel';
      if (_tokenEnd(text, i + token.length)) {
        flush();
        nodes.add({
          'type': 'wallCategory',
          'attrs': {'id': tagId, 'label': tagLabel},
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

  return _doc(nodes);
}

String _doc(List<Map<String, dynamic>> nodes) => jsonEncode({
  'type': 'doc',
  'content': [
    {
      'type': 'paragraph',
      // An empty paragraph with no content at all renders as nothing on web,
      // so a body that is only attachments still needs one space to stand on.
      'content': nodes.isEmpty
          ? [
              {'type': 'text', 'text': ' '},
            ]
          : nodes,
    },
  ],
});

/// A mention ends where a word ends. Without this "@Jo" would also match inside
/// "@Joanne" and swallow the rest of the name into the chip.
bool _tokenEnd(String text, int idx) {
  if (idx >= text.length) return true;
  final c = text[idx];
  return c == ' ' || c == '\n' || c == ',' || c == '.' || c == '!';
}
