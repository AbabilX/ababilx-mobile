import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';
import 'mute_choice.dart';
import 'mute_custom_page.dart';

/// Signal's mute choices as one bottom sheet: four lengths, Always, Only
/// mentions (groups only — in a DM every message is addressed to you), and a
/// custom end time picked on a second page of the SAME sheet. Nothing here
/// opens a dialog; the date and time are chosen inline.
///
/// It only chooses. The caller writes the mute, on its own context, because
/// this sheet is gone by the time the request comes back.
Future<MuteChoice?> showMuteOptionsSheet(
  BuildContext context, {
  required bool allowMentionsOnly,
}) {
  return showModalBottomSheet<MuteChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _MuteSheet(allowMentionsOnly: allowMentionsOnly),
  );
}

const _presets = <(String, Duration)>[
  ('For 1 hour', Duration(hours: 1)),
  ('For 8 hours', Duration(hours: 8)),
  ('For 1 day', Duration(days: 1)),
  ('For 1 week', Duration(days: 7)),
];

class _MuteSheet extends StatefulWidget {
  const _MuteSheet({required this.allowMentionsOnly});

  final bool allowMentionsOnly;

  @override
  State<_MuteSheet> createState() => _MuteSheetState();
}

class _MuteSheetState extends State<_MuteSheet> {
  bool _custom = false;

  void _choose(MuteChoice choice) => Navigator.of(context).pop(choice);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.topCenter,
        child: _custom
            ? MuteCustomPage(
                onBack: () => setState(() => _custom = false),
                onPick: (at) => _choose(MuteChoice.until(at)),
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
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            'Mute notifications',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        for (final (label, duration) in _presets)
          _MuteTile(
            icon: HugeIcons.strokeRoundedClock01,
            label: label,
            onTap: () => _choose(MuteChoice.forDuration(duration)),
          ),
        _MuteTile(
          icon: HugeIcons.strokeRoundedNotificationOff01,
          label: 'Always',
          subtitle: 'Until you unmute',
          onTap: () => _choose(const MuteChoice.always()),
        ),
        if (widget.allowMentionsOnly)
          _MuteTile(
            icon: HugeIcons.strokeRoundedAt,
            label: 'Only mentions',
            subtitle: 'Notify only when someone @mentions or replies to you',
            onTap: () => _choose(const MuteChoice.mentionsOnly()),
          ),
        _MuteTile(
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

class _MuteTile extends StatelessWidget {
  const _MuteTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final List<List<dynamic>> icon;
  final String label;
  final String? subtitle;
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
