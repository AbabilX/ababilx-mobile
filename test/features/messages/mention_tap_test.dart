import 'package:ababilx/features/messages/tiptap_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _body =
    '{"type":"doc","content":[{"type":"paragraph","content":['
    '{"type":"mention","attrs":{"id":"u7","label":"Alvi"}},'
    '{"type":"text","text":" are you coming?"}]}]}';

Future<void> _pump(WidgetTester tester, TiptapViewer viewer) =>
    tester.pumpWidget(MaterialApp(home: Scaffold(body: viewer)));

void main() {
  testWidgets('a mention chip opens the person it names', (tester) async {
    final tapped = <String>[];
    await _pump(
      tester,
      TiptapViewer(
        content: _body,
        onMentionTap: (userId, label) => tapped.add('$userId/$label'),
      ),
    );

    await tester.tap(find.text('@Alvi'));
    await tester.pump();

    expect(tapped, ['u7/Alvi']);
  });

  testWidgets('and is inert where there is nobody to open', (tester) async {
    await _pump(tester, const TiptapViewer(content: _body));

    // No handler, no gesture: the chip must not swallow a tap that belongs to
    // the row underneath it.
    expect(
      find.descendant(
        of: find.byType(TiptapViewer),
        matching: find.byType(GestureDetector),
      ),
      findsNothing,
    );
  });
}
