import 'package:ababilx/features/messages/chat-timeline/composer_input_bar_buttons.dart';
import 'package:ababilx/features/messages/send-later/send_later_sheet.dart';
import 'package:ababilx/features/messages/send-later/send_later_times.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';

void main() {
  Future<List<DateTime?>> open(WidgetTester tester) async {
    final picked = <DateTime?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  picked.add(await showSendLaterSheet(context)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return picked;
  }

  testWidgets('a quick row answers with a time the server takes', (
    tester,
  ) async {
    final picked = await open(tester);
    expect(find.text('Send later'), findsOneWidget);
    expect(find.text('In 1 hour'), findsOneWidget);
    expect(find.text('Tomorrow 9 AM'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);

    await tester.tap(find.text('Tomorrow 9 AM'));
    await tester.pumpAndSettle();
    final at = picked.single!;
    expect(at.hour, 9);
    expect(sendLaterTimeAllowed(at, DateTime.now()), isTrue);
  });

  testWidgets('custom is a wheel on the same sheet, never a dialog', (
    tester,
  ) async {
    final picked = await open(tester);
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(DatePickerDialog), findsNothing);
    expect(find.byType(TimePickerDialog), findsNothing);
    expect(find.byType(BottomSheet), findsOneWidget);

    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();
    expect(sendLaterTimeAllowed(picked.single!, DateTime.now()), isTrue);
  });

  testWidgets('backing out answers nothing', (tester) async {
    final picked = await open(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(picked, [null]);
  });

  testWidgets('the send circle: tap sends, hold schedules', (tester) async {
    var taps = 0, holds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AccentCircle(
              sending: false,
              label: 'Send',
              icon: HugeIcons.strokeRoundedSent,
              rotated: false,
              onTap: () => taps++,
              onLongPress: () => holds++,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(AccentCircle));
    await tester.pump();
    expect((taps, holds), (1, 0));
    await tester.longPress(find.byType(AccentCircle));
    await tester.pump();
    expect((taps, holds), (1, 1));
  });
}
