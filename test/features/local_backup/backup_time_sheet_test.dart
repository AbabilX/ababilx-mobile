import 'package:ababilx/features/local-backup/ui/local_backup_time_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<int?> Function() mount(WidgetTester tester, {required int minute}) {
    int? picked;
    var done = false;
    return () async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                picked = await showBackupTimeSheet(
                  context,
                  minuteOfDay: minute,
                  title: 'Auto backup time',
                  hint: 'Once a day',
                  saveLabel: 'Save',
                );
                done = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return done ? picked : null;
    };
  }

  testWidgets('opens on the current time as a wheel, never a dialog', (
    tester,
  ) async {
    await mount(tester, minute: 21 * 60 + 30)();
    final wheel = tester.widget<CupertinoDatePicker>(
      find.byType(CupertinoDatePicker),
    );
    expect(wheel.mode, CupertinoDatePickerMode.time);
    expect(wheel.initialDateTime.hour, 21);
    expect(wheel.initialDateTime.minute, 30);
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(TimePickerDialog), findsNothing);
    expect(find.text('Once a day'), findsOneWidget);
  });

  testWidgets('Save returns the time; dismissing changes nothing', (
    tester,
  ) async {
    int? picked = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              picked = await showBackupTimeSheet(
                context,
                minuteOfDay: 120,
                title: 'T',
                hint: 'H',
                saveLabel: 'Save',
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(picked, 120);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(picked, isNull);
  });

  test('a time off the wheel\'s step opens on the nearest step', () {
    expect(wheelMinute(21 * 60 + 33), 21 * 60 + 35);
    expect(wheelMinute(23 * 60 + 58), 23 * 60 + 55);
    expect(wheelMinute(0), 0);
  });
}
