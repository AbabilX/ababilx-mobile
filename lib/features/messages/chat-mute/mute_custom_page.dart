import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';
import 'mute_choice.dart';

const _step = 5; // minutes between wheel positions

/// The mute sheet's second page: an inline date-and-time wheel, never the
/// Material date/time dialogs. Bounds mirror the server's
/// (`chatmutedb.MaxMuteDuration`): after now, at most a year out.
class MuteCustomPage extends StatefulWidget {
  const MuteCustomPage({super.key, required this.onBack, required this.onPick});

  final VoidCallback onBack;
  final ValueChanged<DateTime> onPick;

  @override
  State<MuteCustomPage> createState() => _MuteCustomPageState();
}

class _MuteCustomPageState extends State<MuteCustomPage> {
  late final DateTime _min;
  late final DateTime _max;
  late DateTime _picked;
  bool _tooSoon = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _min = _roundUp(now).add(const Duration(minutes: _step));
    _max = now.add(const Duration(days: 365));
    _picked = _roundUp(now.add(const Duration(hours: 1)));
  }

  /// Next wheel position at or after [t], seconds dropped — the wheel asserts
  /// that its initial minute sits on a step.
  static DateTime _roundUp(DateTime t) {
    final base = DateTime(t.year, t.month, t.day, t.hour, t.minute);
    final extra = (_step - base.minute % _step) % _step;
    return base.add(
      Duration(minutes: extra == 0 && t.second > 0 ? _step : extra),
    );
  }

  void _submit() {
    // The sheet may have sat open past the chosen minute.
    if (!_picked.isAfter(DateTime.now())) {
      setState(() => _tooSoon = true);
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
                'Mute until',
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
                minimumDate: _min,
                maximumDate: _max,
                minuteInterval: _step,
                use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
                onDateTimeChanged: (t) => setState(() {
                  _picked = t;
                  _tooSoon = false;
                }),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Text(
              _tooSoon
                  ? 'Pick a time in the future'
                  : 'Muted until ${formatMuteEnd(_picked)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: _tooSoon ? colors.error : colors.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: FilledButton(onPressed: _submit, child: const Text('Mute')),
          ),
        ],
      ),
    );
  }
}
