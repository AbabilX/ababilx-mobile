import 'package:flutter/material.dart';

import '../call_icons.dart';
import 'call_surface.dart';

enum CallButtonTone { neutral, active, danger, accent }

/// Standard diameter for a control on the call bar, and the floor the bar is
/// allowed to shrink to before it starts scrolling instead.
///
/// 58 was the old value and it drew six circles spanning the screen edge to
/// edge with nothing around them — the controls read as six separate buttons
/// dropped on the backdrop rather than one bar. 50 leaves room for the pill
/// [CallControlBar] draws behind them and for a margin either side of it.
const double callButtonDiameter = 50;
const double callButtonMinDiameter = 36;

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
                      size: diameter >= 46 ? 22 : 19,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single row of call controls, grouped inside one rounded pill.
///
/// Two things this fixes. The old bar was a [Wrap] of fixed 58dp buttons:
/// seven of them need 478dp and a 412dp phone has 388, so it broke 5 + 2 and
/// left Hang up orphaned in the second row. And once it did fit on one row it
/// still spread edge to edge over the bare backdrop, so the controls read as
/// loose circles rather than a bar. Dividing the real width keeps one row on
/// every phone; the pill gives the row a body, an inner padding and a margin.
///
/// The pill hugs its contents ([MainAxisSize.min]), so the disconnected state
/// — Leave on its own — comes out as one small rounded button instead of a
/// lone 58dp circle floating in the middle of the screen.
class CallControlBar extends StatelessWidget {
  const CallControlBar({super.key, required this.builder, required this.count});

  /// Built with the resolved diameter, so every control on the row matches.
  final List<Widget> Function(double diameter) builder;
  final int count;

  /// Breathing room between the pill's edge and the outermost control.
  static const double _padding = 8;
  static const double _gap = 10;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // The pill's own padding is not available to the controls, so the
      // division has to happen inside it or the row overflows the pill by
      // exactly that much.
      final available = constraints.maxWidth - _padding * 2;
      final raw = count <= 0
          ? callButtonDiameter
          : (available - (count - 1) * _gap) / count;
      final diameter = raw.clamp(callButtonMinDiameter, callButtonDiameter);
      final children = builder(diameter);
      final row = <Widget>[
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: _gap),
          children[i],
        ],
      ];
      final palette = CallColors.of(context);

      return Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.panel,
            borderRadius: BorderRadius.circular(diameter / 2 + _padding),
          ),
          child: Padding(
            padding: const EdgeInsets.all(_padding),
            child: raw < callButtonMinDiameter
                // Only a genuinely tiny screen gets here, and a squashed row
                // is worse than one the user can push sideways.
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: row),
                  )
                : Row(mainAxisSize: MainAxisSize.min, children: row),
          ),
        ),
      );
    },
  );
}
