import 'package:flutter/material.dart';

import '../call_icons.dart';
import 'call_surface.dart';

enum CallButtonTone { neutral, active, danger, accent }

/// Standard diameter for a control on the call bar, and the floor the bar is
/// allowed to shrink to before it starts scrolling instead.
const double callButtonDiameter = 58;
const double callButtonMinDiameter = 42;

/// One round control on the call bar. "On" states invert to the theme's own
/// text colour, so mute, sharing and a raised hand read without a label.
class CallRoundButton extends StatelessWidget {
  const CallRoundButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.tone = CallButtonTone.neutral,
    this.enabled = true,
    this.busy = false,
    this.diameter = callButtonDiameter,
  });

  final CallGlyph icon;
  final String label;
  final VoidCallback? onTap;
  final CallButtonTone tone;
  final bool enabled;
  final bool busy;

  /// Sized by the caller: the control bar divides the width it actually has,
  /// so seven controls on a narrow phone shrink rather than wrapping onto a
  /// second line and orphaning whichever ones did not fit.
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final palette = CallColors.of(context);
    // "On" states invert against the theme's own onSurface/backdrop pair, so a
    // muted mic or a raised hand reads at a glance in light mode as well.
    final (background, foreground) = switch (tone) {
      CallButtonTone.neutral => (palette.tile, palette.onSurface),
      CallButtonTone.active => (palette.onSurface, palette.backdrop),
      CallButtonTone.danger => (palette.danger, palette.onDanger),
      CallButtonTone.accent => (palette.accent, palette.onAccent),
    };
    final live = enabled && !busy && onTap != null;

    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: live ? background : background.withValues(alpha: 0.4),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: live ? onTap : null,
            child: SizedBox(
              width: diameter,
              height: diameter,
              child: busy
                  ? Padding(
                      padding: EdgeInsets.all(diameter / 3),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    )
                  : CallIcon(
                      icon,
                      color: foreground,
                      size: diameter >= 52 ? 24 : 20,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single row of call controls that never wraps.
///
/// The old bar was a [Wrap] of fixed 58dp buttons: seven of them need 478dp
/// and a 412dp phone has 388, so it broke 5 + 2 and left Hang up orphaned in
/// the second row beside Participants. Dividing the real width instead keeps
/// one row on every phone, and only a genuinely tiny screen scrolls.
class CallControlBar extends StatelessWidget {
  const CallControlBar({super.key, required this.builder, required this.count});

  /// Built with the resolved diameter, so every control on the row matches.
  final List<Widget> Function(double diameter) builder;
  final int count;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 10.0;
      final available = constraints.maxWidth;
      final raw = count <= 0
          ? callButtonDiameter
          : (available - (count - 1) * gap) / count;
      final diameter = raw.clamp(callButtonMinDiameter, callButtonDiameter);
      final children = builder(diameter);
      if (raw < callButtonMinDiameter) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                children[i],
              ],
            ],
          ),
        );
      }
      return Row(
        mainAxisAlignment: children.length == 1
            ? MainAxisAlignment.center
            : MainAxisAlignment.spaceBetween,
        children: children,
      );
    },
  );
}
