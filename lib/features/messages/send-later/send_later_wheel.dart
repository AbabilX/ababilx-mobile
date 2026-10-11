import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';
import 'send_later_times.dart';

/// The send-later sheet's second page: an inline date-and-time wheel, never
/// the Material date/time dialogs. Bounds are the server's: a minute ahead
/// to 120 days.
class SendLaterWheel extends StatefulWidget {
  const SendLaterWheel({
    super.key,
    required this.now,
    required this.action,
    required this.onBack,
    required this.onPick,
  });

  /// When the sheet opened; the wheel's floor.
  final DateTime now;
  final String action;
  final VoidCallback onBack;
  final ValueChanged<DateTime> onPick;

  @override
  State<SendLaterWheel> createState() => _SendLaterWheelState();
}

class _SendLaterWheelState extends State<SendLaterWheel> {
  late DateTime _picked = _minute(widget.now.add(const Duration(hours: 1)));
  bool _outOfRange = false;

  /// Seconds dropped: the wheel shows minutes.
  static DateTime _minute(DateTime t) =>
      DateTime(t.year, t.month, t.day, t.hour, t.minute);

  void _submit() {
    // The sheet may have sat open past the chosen minute.
    if (!sendLaterTimeAllowed(_picked, DateTime.now())) {
      setState(() => _outOfRange = true);
      return;
    }
    widget.onPick(_picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: ChatIcon(
                  HugeIcons.strokeRoundedArrowLeft01,
                  color: colors.onSurface,
                ),
              ),
              const Text(
                'Send at',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
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
                mode: CupertinoDatePickerMode.dateAndTime,
                initialDateTime: _picked,
                minimumDate: _minute(widget.now),
                maximumDate: widget.now.add(sendLaterMaxAhead),
                use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
                onDateTimeChanged: (t) => setState(() {
                  _picked = t;
                  _outOfRange = false;
                }),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Text(
              _outOfRange
                  ? 'Pick a time at least a minute from now'
                  : formatSendAt(_picked),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: _outOfRange ? colors.error : colors.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: FilledButton(onPressed: _submit, child: Text(widget.action)),
          ),
        ],
      ),
    );
  }
}
