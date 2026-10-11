import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';
import 'send_later_times.dart';
import 'send_later_wheel.dart';

/// Picks when a message goes out: quick rows chosen by the time of day, and
/// Custom — a date-and-time wheel on a second page of the SAME sheet, never
/// a dialog. It only chooses; the caller schedules.
Future<DateTime?> showSendLaterSheet(
  BuildContext context, {
  String title = 'Send later',
  String action = 'Schedule',
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _SendLaterSheet(title: title, action: action),
  );
}

class _SendLaterSheet extends StatefulWidget {
  const _SendLaterSheet({required this.title, required this.action});

  final String title;
  final String action;

  @override
  State<_SendLaterSheet> createState() => _SendLaterSheetState();
}

class _SendLaterSheetState extends State<_SendLaterSheet> {
  bool _custom = false;
  late final DateTime _now = DateTime.now();

  /// A preset is built when the sheet opens; one that has since slipped
  /// under a minute away is sent an hour out instead of being refused.
  void _choose(DateTime at) {
    final now = DateTime.now();
    Navigator.of(context).pop(
      sendLaterTimeAllowed(at, now) ? at : now.add(const Duration(hours: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.topCenter,
        child: _custom
            ? SendLaterWheel(
                now: _now,
                action: widget.action,
                onBack: () => setState(() => _custom = false),
                onPick: (at) => Navigator.of(context).pop(at),
              )
            : _list(context),
      ),
    );
  }

  Widget _list(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            widget.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        for (final preset in sendLaterPresets(_now))
          _Tile(
            icon: HugeIcons.strokeRoundedClock01,
            label: preset.label,
            subtitle: formatSendAt(preset.at, now: _now),
            onTap: () => _choose(preset.at),
          ),
        _Tile(
          icon: HugeIcons.strokeRoundedCalendar03,
          label: 'Custom',
          subtitle: 'Pick a date and time',
          onTap: () => setState(() => _custom = true),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final List<List<dynamic>> icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            ChatIcon(icon, size: 20, color: colors.onSurface),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
