import 'package:ababilx/features/messages/chat_list_preview_highlights.dart';
import 'package:ababilx/features/messages/tiptap_plain_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tiptapMentionLabels', () {
    test('reads spaced display names from mention nodes', () {
      const doc =
          '{"type":"doc","content":[{"type":"paragraph","content":['
          '{"type":"mention","attrs":{"id":"u1","label":"John Doe"}},'
          '{"type":"text","text":" check this"}'
          ']}]}';
      expect(tiptapMentionLabels(doc), ['John Doe']);
      expect(tiptapToPreviewText(doc), '@John Doe check this');
    });

    test('sorts longer labels first so a prefix name does not win', () {
      const doc =
          '{"type":"doc","content":[{"type":"paragraph","content":['
          '{"type":"mention","attrs":{"id":"u1","label":"Jo"}},'
          '{"type":"text","text":" and "},'
          '{"type":"mention","attrs":{"id":"u2","label":"Jo Anne"}}'
          ']}]}';
      expect(tiptapMentionLabels(doc), ['Jo Anne', 'Jo']);
    });
  });

  group('findPreviewHighlights', () {
    test('colours the full spaced mention when labels are known', () {
      final hits = findPreviewHighlights(
        '@John Doe check this',
        mentionLabels: const ['John Doe'],
      );
      expect(hits, hasLength(1));
      expect(hits.single.isMention, isTrue);
      expect(
        '@John Doe check this'.substring(hits.single.start, hits.single.end),
        '@John Doe',
      );
    });

    test('without labels, still covers a two-word name', () {
      final hits = findPreviewHighlights('@John Doe hey');
      expect(hits, hasLength(1));
      expect(
        '@John Doe hey'.substring(hits.single.start, hits.single.end),
        '@John Doe',
      );
    });

    test('does not stop at the first space of a known label', () {
      final hits = findPreviewHighlights(
        'ping @Murad Ahmed please',
        mentionLabels: const ['Murad Ahmed'],
      );
      expect(hits.single.end - hits.single.start, '@Murad Ahmed'.length);
    });

    test('an email is one link run, never an @domain mention', () {
      const text = 'Contact: Muradian developer.mozadded@gmail.com';
      final hits = findPreviewHighlights(text);
      expect(hits, hasLength(1));
      expect(hits.single.isUrl, isTrue);
      expect(
        text.substring(hits.single.start, hits.single.end),
        'developer.mozadded@gmail.com',
      );
    });

    test('a mention glued to a word is not a mention', () {
      expect(findPreviewHighlights('abc@gmail'), isEmpty);
      expect(findPreviewHighlights('hi @Murad').single.isMention, isTrue);
    });
  });
}
