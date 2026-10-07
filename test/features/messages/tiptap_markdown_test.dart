import 'dart:convert';

import 'package:ababilx/features/messages/markdown/message_markdown.dart';
import 'package:ababilx/features/messages/markdown/tiptap_markdown.dart';
import 'package:ababilx/features/messages/tiptap_encode.dart';
import 'package:ababilx/features/messages/tiptap_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

String _doc(List<Map<String, dynamic>> blocks) =>
    jsonEncode({'type': 'doc', 'content': blocks});

Map<String, dynamic> _p(List<Map<String, dynamic>> inline) => {
  'type': 'paragraph',
  'content': inline,
};

Map<String, dynamic> _t(String text, [List<String> marks = const []]) => {
  'type': 'text',
  'text': text,
  if (marks.isNotEmpty)
    'marks': [
      for (final m in marks) {'type': m},
    ],
};

Map<String, dynamic> _item(String text) => {
  'type': 'listItem',
  'content': [
    _p([_t(text)]),
  ],
};

void main() {
  group('markdownOfBody', () {
    test('plain text is markdown already', () {
      expect(markdownOfBody('hello there'), 'hello there');
      expect(markdownOfBody('{not json'), '{not json');
      expect(markdownOfBody(''), isNull);
      expect(markdownOfBody(null), isNull);
    });

    test('JSON that is not a TipTap doc is left to the TipTap renderer', () {
      expect(markdownOfBody('{"type":"kanban","id":"1"}'), isNull);
    });

    test('marks become markdown, edge spaces stay outside', () {
      final body = _doc([
        _p([
          _t('a '),
          _t('bold ', ['bold']),
          _t('it', ['italic']),
          _t(' '),
          _t('gone', ['strike']),
          _t(' '),
          _t('x()', ['code', 'bold']),
          _t(' '),
          _t('under', ['underline']),
        ]),
      ]);
      expect(
        markdownOfBody(body),
        'a **bold** *it* ~~gone~~ `x()` <u>under</u>',
      );
    });

    test('a link mark becomes a markdown link', () {
      final body = _doc([
        _p([
          {
            'type': 'text',
            'text': 'docs',
            'marks': [
              {
                'type': 'link',
                'attrs': {'href': 'https://a.dev/x y'},
              },
            ],
          },
        ]),
      ]);
      expect(markdownOfBody(body), '[docs](https://a.dev/x%20y)');
    });

    test('blocks: heading, lists, tasks, quote, code, rule', () {
      final body = _doc([
        {
          'type': 'heading',
          'attrs': {'level': 2},
          'content': [_t('Plan')],
        },
        {
          'type': 'bulletList',
          'content': [
            _item('one'),
            {
              'type': 'listItem',
              'content': [
                _p([_t('two')]),
                {
                  'type': 'orderedList',
                  'attrs': {'start': 3},
                  'content': [_item('deep')],
                },
              ],
            },
          ],
        },
        {
          'type': 'taskList',
          'content': [
            {
              'type': 'taskItem',
              'attrs': {'checked': true},
              'content': [
                _p([_t('done')]),
              ],
            },
          ],
        },
        {
          'type': 'blockquote',
          'content': [
            _p([_t('said')]),
          ],
        },
        {
          'type': 'codeBlock',
          'attrs': {'language': 'dart'},
          'content': [_t('var a = 1;')],
        },
        {'type': 'horizontalRule'},
      ]);
      expect(
        markdownOfBody(body),
        '## Plan\n- one\n- two\n  3. deep\n- [x] done\n> said\n'
        '```dart\nvar a = 1;\n```\n---',
      );
    });

    test('a mention becomes a link on the mention scheme', () {
      final body = encodeTiptapBody(
        plain: '@Ann **look**',
        mentionByLabel: {'Ann': 'u-1'},
      );
      expect(markdownOfBody(body), '[@Ann](mention:u-1) **look**');
    });
  });

  group('bubble', () {
    Future<void> pump(
      WidgetTester tester,
      String body, {
      void Function(String, String)? onMention,
    }) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TiptapViewer(
            content: body,
            markdown: true,
            onMentionTap: onMention,
          ),
        ),
      ),
    );

    testWidgets('a rich TipTap body is drawn by gpt_markdown', (tester) async {
      await pump(
        tester,
        _doc([
          _p([
            _t('very ', ['bold']),
            _t('nice'),
          ]),
        ]),
      );
      expect(find.byType(MessageMarkdown), findsOneWidget);
      expect(find.textContaining('**', findRichText: true), findsNothing);
      expect(find.textContaining('very', findRichText: true), findsWidgets);
    });

    testWidgets('tapping a mention opens that person, not a link', (
      tester,
    ) async {
      String? opened;
      await pump(
        tester,
        encodeTiptapBody(plain: 'hi @Ann', mentionByLabel: {'Ann': 'u-1'}),
        onMention: (id, label) => opened = '$id|$label',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('mention:', findRichText: true), findsNothing);

      // gpt_markdown hit-tests its own tap runs, so press the words themselves.
      final paragraph = tester
          .renderObjectList<RenderParagraph>(
            find.byWidgetPredicate((w) => w is RichText),
          )
          .firstWhere((p) => p.text.toPlainText().contains('@Ann'));
      final start = paragraph.text.toPlainText().indexOf('@Ann');
      final box = paragraph
          .getBoxesForSelection(
            TextSelection(baseOffset: start, extentOffset: start + 4),
          )
          .first
          .toRect();
      await tester.tapAt(paragraph.localToGlobal(box.center));
      await tester.pump();
      expect(opened, 'u-1|Ann');
    });

    testWidgets('a markdown image is never fetched', (tester) async {
      await pump(tester, '![x](https://evil.example/p.png)');
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.text('https://evil.example/p.png'), findsOneWidget);
    });
  });
}
