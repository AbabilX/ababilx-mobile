import 'dart:convert';

import 'package:ababilx/features/messages/chat-timeline/composer_highlight_controller.dart';
import 'package:ababilx/features/messages/tiptap_encode.dart';
import 'package:flutter_test/flutter_test.dart';

List<dynamic> _nodes(String body) =>
    (jsonDecode(body)['content'] as List).first['content'] as List;

/// A picked name followed by punctuation was sent as plain text, so every
/// reader drew only the first word of a spaced name.
void main() {
  const who = {'Sharmin Sorna': 'u1'};

  for (final tail in ['?', ':', ')', '।', '😀', "'s"]) {
    test('a mention followed by "$tail" is still a mention node', () {
      final nodes = _nodes(
        encodeTiptapBody(
          plain: 'hi @Sharmin Sorna$tail ok',
          mentionByLabel: who,
        ),
      );
      expect(nodes[1], {
        'type': 'mention',
        'attrs': {'id': 'u1', 'label': 'Sharmin Sorna'},
      });
    });
  }

  test('a longer word is not the mention', () {
    for (final plain in ['@Sharmin Sornax', '@Sharmin Sornaর']) {
      final nodes = _nodes(encodeTiptapBody(plain: plain, mentionByLabel: who));
      expect(nodes.single['type'], 'text');
    }
  });

  test('the composer paints exactly what the encoder sends', () {
    const text = 'hi @Sharmin Sorna? and @Sharmin Sornax';
    final hits = findComposerHighlights(text, who.keys);
    expect(
      [for (final h in hits) text.substring(h.start, h.end)],
      ['@Sharmin Sorna'],
    );
  });
}
