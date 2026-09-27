import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ababilx/features/messages/chat-timeline/composer_input_bar.dart';
import 'package:ababilx/features/messages/chat-timeline/composer_keyboard_content.dart';

KeyboardInsertedContent _content(String mime, String uri, [List<int>? data]) =>
    KeyboardInsertedContent(
      mimeType: mime,
      uri: uri,
      data: data == null ? null : Uint8List.fromList(data),
    );

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  test('a Gboard GIF keeps its own name and type', () {
    final file = keyboardContentFile(
      _content(
        'image/gif',
        'content://com.google.android.inputmethod.latin.fileprovider/x/dance.gif',
        [1, 2, 3],
      ),
      now: now,
    );
    expect(file, isNotNull);
    expect(file!.fileName, 'dance.gif');
    expect(file.contentType, 'image/gif');
    expect(file.bytes, [1, 2, 3]);
  });

  test('a sticker with no usable name gets one from its type', () {
    final file = keyboardContentFile(
      _content('image/webp', 'content://keyboard/sticker/42', [9]),
      now: now,
    );
    expect(file!.fileName, 'sticker-1700000000000.webp');
    expect(file.contentType, 'image/webp');
  });

  test('image/jpg is sent as image/jpeg', () {
    final file = keyboardContentFile(
      _content('image/jpg', 'content://k/a b.jpg', [1]),
      now: now,
    );
    expect(file!.contentType, 'image/jpeg');
    // A space is not a safe name; one is made up instead.
    expect(file.fileName, 'sticker-1700000000000.jpg');
  });

  test('no bytes or a non-image refuses', () {
    expect(
      keyboardContentFile(_content('image/gif', 'content://k/a.gif')),
      null,
    );
    expect(
      keyboardContentFile(_content('image/gif', 'content://k/a.gif', [])),
      null,
    );
    expect(
      keyboardContentFile(_content('video/mp4', 'content://k/a.mp4', [1])),
      null,
    );
  });

  Widget bar({ValueChanged<KeyboardInsertedContent>? onInsert}) => MaterialApp(
    home: Scaffold(
      body: ComposerInputBar(
        controller: TextEditingController(),
        focusNode: FocusNode(),
        hint: 'Message',
        sending: false,
        canSend: false,
        attachmentOpen: false,
        onEmoji: () {},
        onCamera: () {},
        onVoice: () {},
        onPlus: () {},
        onSend: () {},
        onContentInserted: onInsert,
      ),
    ),
  );

  testWidgets('the chat field tells the keyboard it takes GIFs and stickers', (
    tester,
  ) async {
    final got = <KeyboardInsertedContent>[];
    await tester.pumpWidget(bar(onInsert: got.add));
    final field = tester.widget<TextField>(find.byType(TextField));
    final config = field.contentInsertionConfiguration;
    expect(config, isNotNull);
    expect(config!.allowedMimeTypes, containsAll(['image/gif', 'image/webp']));
    final gif = _content('image/gif', 'content://k/a.gif', [1]);
    config.onContentInserted(gif);
    expect(got, [gif]);
  });

  testWidgets('no handler leaves the field text-only', (tester) async {
    await tester.pumpWidget(bar());
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.contentInsertionConfiguration, isNull);
  });
}
