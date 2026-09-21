import 'package:ababilx/features/messages/chat-timeline/composer_expanded_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opening and closing the @ popover keeps the field focused', (
    tester,
  ) async {
    final focus = FocusNode();
    final picker = ValueNotifier<bool>(false);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: picker,
            builder: (context, show, _) => Align(
              alignment: Alignment.bottomCenter,
              child: ComposerExpandedShell(
                pending: const [],
                onRemove: (_) {},
                onAddPhoto: () {},
                mentionPicker: show ? const Text('popover') : null,
                field: TextField(focusNode: focus),
              ),
            ),
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    final field = tester.state(find.byType(EditableText));

    picker.value = true;
    await tester.pump();
    expect(tester.state(find.byType(EditableText)), same(field));
    expect(focus.hasFocus, isTrue);

    picker.value = false;
    await tester.pump();
    expect(tester.state(find.byType(EditableText)), same(field));
    expect(focus.hasFocus, isTrue);
  });
}
