import 'dart:async';

import 'package:flutter/material.dart';

import '../call_icons.dart';
import '../providers/group_call_state.dart';
import 'call_stage_view.dart';
import 'call_surface.dart';

/// Name, how long this has been going, and the two layout switches.
class GroupCallHeader extends StatefulWidget {
  const GroupCallHeader({
    super.key,
    required this.state,
    required this.view,
    required this.onView,
    required this.onParticipants,
    required this.onMinimize,
  });

  final GroupCallState state;
  final CallStageView view;
  final ValueChanged<CallStageView> onView;
  final VoidCallback onParticipants;
  final VoidCallback onMinimize;

  @override
  State<GroupCallHeader> createState() => _GroupCallHeaderState();
}

class _GroupCallHeaderState extends State<GroupCallHeader> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // A running duration is not a state change, so nothing else rebuilds for it.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = CallColors.of(context);
    final state = widget.state;
    final elapsed = callElapsedLabel(state.call?.startedAt);
    final subtitle = state.phase == GroupCallPhase.joining
        ? 'Joining…'
        : [
            participantCountLabel(state.participants.length),
            if (elapsed.isNotEmpty) elapsed,
            if (state.muted) 'You are muted',
          ].join(' · ');

    return Row(
      children: [
        _HeaderButton(
          icon: CallIcons.minimize,
          label: 'Minimize call',
          onTap: widget.onMinimize,
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                state.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.faint, fontSize: 12),
              ),
            ],
          ),
        ),
        _HeaderButton(
          icon: widget.view == CallStageView.grid
              ? CallIcons.speakerView
              : CallIcons.gridView,
          label: widget.view == CallStageView.grid
              ? 'Speaker view'
              : 'Grid view',
          onTap: () => widget.onView(
            widget.view == CallStageView.grid
                ? CallStageView.speaker
                : CallStageView.grid,
          ),
        ),
        _HeaderButton(
          icon: CallIcons.participants,
          label: 'Participants',
          onTap: widget.onParticipants,
        ),
      ],
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final CallGlyph icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onTap,
    icon: CallIcon(icon, color: CallColors.of(context).onSurface, size: 22),
  );
}
