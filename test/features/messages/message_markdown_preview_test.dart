import 'package:ababilx/features/messages/markdown/message_markdown_preview.dart';
import 'package:ababilx/features/messages/tiptap_plain_text.dart';
import 'package:flutter_test/flutter_test.dart';

String _doc(String text) =>
    '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":${_json(text)}}]}]}';
String _json(String s) =>
    '"${s.replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll('\n', '\\n')}"';

void main() {
  test('inline marks become their words', () {
    expect(
      tiptapToPreviewText(
        _doc('**Done** with `build` and ~~old~~ [docs](https://x.io)'),
      ),
      'Done with build and old docs',
    );
  });

  test('block syntax is dropped, lines joined', () {
    expect(
      tiptapToPreviewText(
        _doc('# Release notes\n- first\n- [x] second\n> quoted\n---'),
      ),
      'Release notes first second quoted',
    );
  });

  test('tables read as cells, divider dropped', () {
    expect(
      tiptapToPreviewText(_doc('| Name | Qty |\n|---|---|\n| Tea | 2 |')),
      'Name · Qty Tea · 2',
    );
  });

  test('fenced code keeps its content, not the fence', () {
    expect(
      tiptapToPreviewText(_doc('```dart\nfinal a = 1;\n```')),
      'final a = 1;',
    );
  });

  test('italic stripped, snake_case and arithmetic untouched', () {
    expect(
      markdownToPreviewText('**x** and *soft* in my_var_name'),
      'x and soft in my_var_name',
    );
    expect(tiptapToPreviewText(_doc('2 * 3 = 6')), '2 * 3 = 6');
  });

  test('ordinary text is unchanged', () {
    expect(tiptapToPreviewText(_doc('hello #team')), 'hello #team');
  });
}
