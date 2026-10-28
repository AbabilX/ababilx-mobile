import 'package:ababilx/features/messages/chat-timeline/composer_format.dart';
import 'package:ababilx/features/messages/chat-timeline/composer_format_menu.dart';
import 'package:ababilx/features/messages/chat-timeline/composer_highlight_controller.dart';
import 'package:ababilx/features/messages/chat-timeline/composer_input_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

TextEditingValue _sel(String text, int start, int end) => TextEditingValue(
  text: text,
  selection: TextSelection(baseOffset: start, extentOffset: end),
);

class _Clipboard {
  String text = '';

  Future<Object?> handle(MethodCall call) async {
    switch (call.method) {
      case 'Clipboard.setData':
        text = (call.arguments as Map)['text'] as String? ?? '';
        return null;
      case 'Clipboard.getData':
        return <String, dynamic>{'text': text};
      case 'Clipboard.hasStrings':
        return <String, dynamic>{'value': text.isNotEmpty};
      default:
        return null;
    }
  }
}

String _inner(TextEditingValue value) {
  final sel = value.selection;
  return value.text.substring(sel.start, sel.end);
}

void main() {
  test('bold wraps the words and leaves the edge spaces outside', () {
    final next = applyComposerFormat(
      _sel('  hi  ', 0, 6),
      format: ComposerFormat.bold,
    );
    expect(next.text, '  **hi**  ');
    expect(_inner(next), 'hi');
  });

  test('bold wraps a whole line of words', () {
    final next = applyComposerFormat(
      _sel('hello world', 0, 11),
      format: ComposerFormat.bold,
    );
    expect(next.text, '**hello world**');
    expect(_inner(next), 'hello world');
  });

  test('bold wraps each line of a selection', () {
    const raw = 'one two\nthree';
    final next = applyComposerFormat(
      _sel(raw, 0, raw.length),
      format: ComposerFormat.bold,
    );
    expect(next.text, '**one two**\n**three**');
  });

  test('bold again unwraps each line', () {
    const raw = '**one two**\n**three**';
    final next = applyComposerFormat(
      _sel(raw, 0, raw.length),
      format: ComposerFormat.bold,
    );
    expect(next.text, 'one two\nthree');
  });

  test('bold on a bold word removes it', () {
    final next = applyComposerFormat(
      _sel('**hi**', 2, 4),
      format: ComposerFormat.bold,
    );
    expect(next.text, 'hi');
    expect(_inner(next), 'hi');
  });

  test('italic on a bold word adds italic without eating the bold', () {
    final next = applyComposerFormat(
      _sel('**hi**', 2, 4),
      format: ComposerFormat.italic,
    );
    expect(next.text, '***hi***');
    expect(_inner(next), 'hi');
  });

  test('a collapsed caret does nothing', () {
    final value = _sel('hi', 1, 1);
    expect(applyComposerFormat(value, format: ComposerFormat.bold), value);
  });

  test('a link uses the address and keeps the selected words', () {
    final next = applyComposerFormat(
      _sel('see hi now', 4, 6),
      format: ComposerFormat.link,
      linkUrl: 'https://example.com/a',
    );
    expect(next.text, 'see [hi](https://example.com/a) now');
    expect(_inner(next), 'hi');
  });

  test('a link turns a line break into a space', () {
    const raw = 'one\ntwo';
    final next = applyComposerFormat(
      _sel(raw, 0, raw.length),
      format: ComposerFormat.link,
      linkUrl: 'https://example.com',
    );
    expect(next.text, '[one two](https://example.com)');
    expect(_inner(next), 'one two');
  });

  test('linking again replaces the address', () {
    final next = applyComposerFormat(
      _sel('see [hi](https://a.com) now', 5, 7),
      format: ComposerFormat.link,
      linkUrl: 'https://b.com',
    );
    expect(next.text, 'see [hi](https://b.com) now');
    expect(_inner(next), 'hi');
  });

  test('remove deletes the selected word and the space it leaves', () {
    final next = applyComposerFormat(
      _sel('say hello there', 4, 9),
      format: ComposerFormat.remove,
    );
    expect(next.text, 'say there');
    expect(next.selection.isCollapsed, isTrue);
    expect(next.selection.start, 4);
  });

  test('remove deletes a formatted word together with its marks', () {
    final next = applyComposerFormat(
      _sel('**hi** there', 2, 4),
      format: ComposerFormat.remove,
    );
    expect(next.text, 'there');
  });

  test('remove deletes a whole line and its line break', () {
    final next = applyComposerFormat(
      _sel('keep\ngone\nstay', 5, 9),
      format: ComposerFormat.remove,
    );
    expect(next.text, 'keep\nstay');
  });

  test('remove deletes only the letters that were selected', () {
    final next = applyComposerFormat(
      _sel('hello', 0, 3),
      format: ComposerFormat.remove,
    );
    expect(next.text, 'lo');
  });

  test('only an http address is a link', () {
    expect(normalizeComposerLinkUrl('example.com/a'), 'https://example.com/a');
    expect(normalizeComposerLinkUrl('  HTTPS://OK.com/x '), 'https://ok.com/x');
    expect(normalizeComposerLinkUrl('javascript:alert(1)'), isNull);
    expect(normalizeComposerLinkUrl('file:///etc/passwd'), isNull);
    expect(normalizeComposerLinkUrl('https://user:pass@evil.com'), isNull);
    expect(normalizeComposerLinkUrl(''), isNull);
    expect(normalizeComposerLinkUrl('https://'), isNull);
  });

  test('emphasis ranges cover the words, not the marks', () {
    expect(findComposerEmphasis('**hi** *yo*'), [
      const ComposerEmphasis(2, 4, bold: true),
      const ComposerEmphasis(8, 10, italic: true),
    ]);
  });

  testWidgets(
    'selected words are drawn bold and the marks stay the same length',
    (tester) async {
      final ctrl = ComposerHighlightController(
        text: '**hi**',
        mentionLabels: () => const [],
      );
      late TextSpan span;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              span = ctrl.buildTextSpan(context: context, withComposing: false);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(span.toPlainText(), '**hi**');
      final bold = span.children!.whereType<TextSpan>().where(
        (s) => s.style?.fontWeight == FontWeight.w700,
      );
      expect(bold.single.toPlainText(), 'hi');
    },
  );

  testWidgets('selecting text offers bold, and bold wraps the word', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final controller = TextEditingController(text: 'hello');
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComposerInputBar(
              controller: controller,
              focusNode: focus,
              hint: 'Message',
              sending: false,
              canSend: true,
              attachmentOpen: false,
              onCamera: () {},
              onVoice: () {},
              onPlus: () {},
              onSend: () {},
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 5,
      );
      await tester.pump();
      final editor = tester.state<EditableTextState>(find.byType(EditableText));
      expect(editor.showToolbar(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byKey(composerFormatBoldKey), findsOneWidget);
      expect(find.byKey(composerFormatItalicKey), findsOneWidget);
      expect(find.byKey(composerFormatLinkKey), findsOneWidget);
      expect(find.byKey(composerFormatRemoveKey), findsOneWidget);
      expect(find.byKey(composerFormatCutKey), findsOneWidget);
      expect(find.byKey(composerFormatCopyKey), findsOneWidget);
      expect(find.byKey(composerFormatPasteKey), findsOneWidget);
      expect(find.text('Cut'), findsNothing);
      expect(find.text('Copy'), findsNothing);
      expect(find.text('Paste'), findsNothing);
      await tester.tap(find.byKey(composerFormatBoldKey));
      await tester.pump();
      expect(controller.text, '**hello**');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('a line selection opens the bar on its own', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      const draft = 'hello world\nsecond line';
      final controller = TextEditingController(text: draft);
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComposerInputBar(
              controller: controller,
              focusNode: focus,
              hint: 'Message',
              sending: false,
              canSend: true,
              attachmentOpen: false,
              onCamera: () {},
              onVoice: () {},
              onPlus: () {},
              onSend: () {},
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: draft.length,
      );
      await tester.pump(const Duration(milliseconds: 320));
      await tester.pumpAndSettle();
      expect(find.byKey(composerFormatBoldKey), findsOneWidget);
      await tester.tap(find.byKey(composerFormatBoldKey));
      await tester.pump();
      expect(controller.text, '**hello world**\n**second line**');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('cut, copy and paste act on the selection', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final clipboard = _Clipboard();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      clipboard.handle,
    );
    try {
      final controller = TextEditingController(text: 'hello world');
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComposerInputBar(
              controller: controller,
              focusNode: focus,
              hint: 'Message',
              sending: false,
              canSend: true,
              attachmentOpen: false,
              onCamera: () {},
              onVoice: () {},
              onPlus: () {},
              onSend: () {},
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 5,
      );
      await tester.pump();
      final editor = tester.state<EditableTextState>(find.byType(EditableText));
      expect(editor.showToolbar(), isTrue);
      await tester.pump();

      await tester.tap(find.byKey(composerFormatCopyKey));
      await tester.pump();
      expect(clipboard.text, 'hello');
      expect(controller.text, 'hello world');

      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 5,
      );
      await tester.pump();
      expect(editor.showToolbar(), isTrue);
      await tester.pump();
      await tester.tap(find.byKey(composerFormatCutKey));
      await tester.pump();
      expect(controller.text, ' world');
      expect(clipboard.text, 'hello');

      clipboard.text = 'X';
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      );
      await tester.pump();
      expect(editor.showToolbar(), isTrue);
      await tester.pump();
      await tester.tap(find.byKey(composerFormatPasteKey));
      await tester.pump();
      expect(controller.text, 'X');
    } finally {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('the link sheet accepts a bare address', (tester) async {
    String? got;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                got = await askComposerLink(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'example.com/a');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(got, 'https://example.com/a');
  });
}
