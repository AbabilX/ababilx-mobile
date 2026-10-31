import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

const _wheelStep = 5;

/// [minuteOfDay] on the wheel's nearest step, within the same day: the wheel
/// asserts that its first minute sits on a step.
int wheelMinute(int minuteOfDay) {
  final rounded = ((minuteOfDay + _wheelStep ~/ 2) ~/ _wheelStep) * _wheelStep;
  return rounded >= 24 * 60 ? 24 * 60 - _wheelStep : rounded;
}

/// The daily backup's time, as an inline wheel on a bottom sheet (never the
/// Material time dialog). The minute of day, or null when dismissed.
Future<int?> showBackupTimeSheet(
  BuildContext context, {
  required int minuteOfDay,
  required String title,
  required String hint,
  required String saveLabel,
}) {
  final start = wheelMinute(minuteOfDay);
  var picked = start;
  return showModalBottomSheet<int>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) {
      final theme = Theme.of(sheet);
      final colors = theme.colorScheme;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                hint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              SizedBox(
                height: 200,
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    brightness: theme.brightness,
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: TextStyle(
                        fontSize: 19,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    minuteInterval: _wheelStep,
                    initialDateTime: DateTime(
                      2026,
                      1,
                      1,
                      start ~/ 60,
                      start % 60,
                    ),
                    onDateTimeChanged: (t) => picked = t.hour * 60 + t.minute,
                  ),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: () => Navigator.of(sheet).pop(picked),
                child: Text(saveLabel),
              ),
            ],
          ),
        ),
      );
    },
  );
}
