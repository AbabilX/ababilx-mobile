import 'dart:convert';

import 'package:ababilx/features/messages/markdown/message_markdown.dart';
import 'package:ababilx/features/messages/markdown/message_markdown_source.dart';
import 'package:ababilx/features/messages/tiptap_encode.dart';
import 'package:ababilx/features/messages/tiptap_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _doc(List<Map<String, dynamic>> paragraphs) =>
    jsonEncode({'type': 'doc', 'content': paragraphs});

Map<String, dynamic> _p(List<Map<String, dynamic>> inline) => {
  'type': 'paragraph',
  'content': inline,
};

Map<String, dynamic> _t(String text, {List<Map<String, dynamic>>? marks}) => {
  'type': 'text',
  'text': text,
  'marks': ?marks,
};

void main() {
  group('markdownSourceOf', () {
    test('plain text with markdown is taken as it is', () {
      expect(markdownSourceOf('**Deploy** done'), '**Deploy** done');
      expect(markdownSourceOf('# Title\nbody'), '# Title\nbody');
      expect(markdownSourceOf('- one\n- two'), '- one\n- two');
      expect(markdownSourceOf('1. first\n2. second'), '1. first\n2. second');
      expect(markdownSourceOf('```\ncode\n```'), '```\ncode\n```');
      expect(markdownSourceOf('run `flutter test`'), 'run `flutter test`');
      expect(markdownSourceOf('see [docs](https://a.dev)'), isNotNull);
      expect(markdownSourceOf('| a | b |\n|---|---|\n| 1 | 2 |'), isNotNull);
      expect(markdownSourceOf('> quoted'), '> quoted');
    });

    test('ordinary messages stay on the TipTap renderer', () {
      expect(markdownSourceOf('hello there'), isNull);
      expect(markdownSourceOf('2 * 3 = 6'), isNull);
      expect(markdownSourceOf('price is \$5 - cheap'), isNull);
      expect(markdownSourceOf('#hashtag'), isNull);
      expect(markdownSourceOf('https://ababilx.com'), isNull);
      expect(markdownSourceOf(''), isNull);
      expect(markdownSourceOf(null), isNull);
    });

    test(
      'a phone-typed body (one paragraph, newlines in the text) qualifies',
      () {
        final body = encodeTiptapBody(plain: '## Plan\n- ship\n- test');
        expect(markdownSourceOf(body), '## Plan\n- ship\n- test');
      },
    );

    test('web paragraphs are joined line by line', () {
      final body = _doc([
        _p([_t('- a')]),
        _p([_t('- b')]),
      ]);
      expect(markdownSourceOf(body), '- a\n- b');
    });

    test('a doc with real marks keeps its own formatting', () {
      final body = _doc([
        _p([
          _t(
            '**x**',
            marks: [
              {'type': 'bold'},
            ],
          ),
        ]),
      ]);
      expect(markdownSourceOf(body), isNull);
    });

    test('a mention keeps the TipTap renderer so the chip stays tappable', () {
      final body = encodeTiptapBody(
        plain: '@Ann **look**',
        mentionByLabel: {'Ann': 'u1'},
      );
      expect(markdownSourceOf(body), isNull);
    });

    test('a rich block (list node) is not re-read as markdown', () {
      final body = jsonEncode({
        'type': 'doc',
        'content': [
          {'type': 'bulletList', 'content': []},
        ],
      });
      expect(markdownSourceOf(body), isNull);
    });
  });

  group('TiptapViewer(markdown: true)', () {
    Future<void> pump(WidgetTester tester, String body, {bool md = true}) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TiptapViewer(content: body, markdown: md),
            ),
          ),
        );

    testWidgets('draws markdown without its syntax', (tester) async {
      await pump(tester, encodeTiptapBody(plain: '**Deploy** finished'));
      expect(find.byType(MessageMarkdown), findsOneWidget);
      expect(find.textContaining('**', findRichText: true), findsNothing);
      expect(find.textContaining('Deploy', findRichText: true), findsWidgets);
    });

    testWidgets('plain chat goes through markdown too', (tester) async {
      await pump(tester, encodeTiptapBody(plain: 'just saying hi'));
      expect(find.byType(MessageMarkdown), findsOneWidget);
      expect(
        find.textContaining('just saying hi', findRichText: true),
        findsWidgets,
      );
    });

    testWidgets('is off unless asked for', (tester) async {
      await pump(tester, encodeTiptapBody(plain: '**x**'), md: false);
      expect(find.byType(MessageMarkdown), findsNothing);
    });
  });
}
