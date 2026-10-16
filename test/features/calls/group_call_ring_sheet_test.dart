import 'package:ababilx/features/calls/group/call-ui/ring_picker_sheet.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _members = [
  ChatMember(userId: 'a', name: 'Alice', joinedAt: ''),
  ChatMember(userId: 'b', name: 'Bob', joinedAt: ''),
  ChatMember(userId: 'c', name: 'Cara', joinedAt: ''),
];

/// Opens the sheet over a bare app and returns what it answered.
Future<RingPick?> _run(
  WidgetTester tester,
  Future<void> Function() act, {
  Set<String>? selected,
}) async {
  RingPick? result;
  var answered = false;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showRingPickerSheet(
              context,
              members: _members,
              selected: selected,
            );
            answered = true;
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await act();
  await tester.pumpAndSettle();
  expect(answered, isTrue, reason: 'sheet should have closed');
  return result;
}

void main() {
  testWidgets('everyone ticked answers "everyone" (no list sent)', (
    tester,
  ) async {
    final pick = await _run(
      tester,
      () => tester.tap(find.text('Ring everyone')),
    );
    expect(pick, isNotNull);
    expect(pick!.ids, isNull);
  });

  testWidgets('unticking one person rings the rest', (tester) async {
    final pick = await _run(tester, () async {
      await tester.tap(find.text('Bob'));
      await tester.pump();
      expect(find.text('Ring 2 people'), findsOneWidget);
      await tester.tap(find.text('Ring 2 people'));
    });
    expect(pick!.ids, {'a', 'c'});
  });

  testWidgets('Everyone clears a full pick, then nobody rings', (tester) async {
    final pick = await _run(tester, () async {
      await tester.tap(find.text('Everyone'));
      await tester.pump();
      await tester.tap(find.text('Ring nobody'));
    });
    expect(pick!.ids, isEmpty);
  });

  testWidgets('reopening keeps the earlier pick', (tester) async {
    final pick = await _run(
      tester,
      () => tester.tap(find.text('Ring 1 person')),
      selected: {'c'},
    );
    expect(pick!.ids, {'c'});
  });

  testWidgets('backing out answers null, not "everyone"', (tester) async {
    final pick = await _run(tester, () async {
      await tester.tapAt(const Offset(10, 10)); // scrim
    });
    expect(pick, isNull);
  });
}
