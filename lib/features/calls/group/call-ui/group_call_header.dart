import 'dart:async';

import 'package:flutter/material.dart';

import '../call_icons.dart';
import '../providers/group_call_state.dart';
import 'call_stage_view.dart';
import 'call_surface.dart';

/// Name, how long this has been going, layout switch, and speaker routing.
///
/// Speaker lives here (beside participants) instead of the bottom bar — that
/// bar is for in-call actions; earpiece/loudspeaker is device routing.
class GroupCallHeader extends StatefulWidget {
  const GroupCallHeader({
    super.key,
    required this.state,
    required this.view,
    required this.onView,
    required this.onParticipants,
    required this.onToggleSpeaker,
    required this.onMinimize,
  });

  final GroupCallState state;
  final CallStageView view;
  final ValueChanged<CallStageView> onView;
  final VoidCallback onParticipants;
  final VoidCallback onToggleSpeaker;
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
            callPresenceLabel(state.participants.length),
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
        if (state.phase == GroupCallPhase.connected)
          _HeaderButton(
            icon: state.speaker ? CallIcons.speakerOn : CallIcons.speakerOff,
            label: state.speaker ? 'Speaker on' : 'Earpiece',
            active: state.speaker,
            onTap: widget.onToggleSpeaker,
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
    this.active = false,
  });

  final CallGlyph icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final palette = CallColors.of(context);
    final fg = active ? palette.backdrop : palette.onSurface;
    return IconButton(
      tooltip: label,
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: active ? palette.onSurface : null,
        foregroundColor: fg,
      ),
      icon: CallIcon(icon, color: fg, size: 22),
    );
  }
}
