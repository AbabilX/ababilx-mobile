import 'package:ababilx/features/messages/tiptap_plain_text.dart';
import 'package:flutter_test/flutter_test.dart';

const _doc =
    '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text",'
    '"text":"Ship it"}]},{"type":"paragraph","content":[{"type":"text",'
    '"text":"tomorrow"}]}]}';

void main() {
  group('tiptapToPreviewText', () {
    test('reads a TipTap doc rather than showing its JSON', () {
      // The quote block on a reply used the raw body and rendered
      // `{"type":"doc","content":[…` at the reader.
      final preview = tiptapToPreviewText(_doc);
      expect(preview, 'Ship it tomorrow');
      expect(preview, isNot(contains('"type"')));
    });

    test('collapses paragraph breaks so a one-line preview stays one line', () {
      expect(tiptapToPlainText(_doc), 'Ship it\ntomorrow');
      expect(tiptapToPreviewText(_doc), isNot(contains('\n')));
    });

    test('plain text passes through untouched', () {
      expect(tiptapToPreviewText('just a string'), 'just a string');
    });

    test('empty and null bodies are empty', () {
      expect(tiptapToPreviewText(null), '');
      expect(tiptapToPreviewText('   '), '');
    });
  });
}
