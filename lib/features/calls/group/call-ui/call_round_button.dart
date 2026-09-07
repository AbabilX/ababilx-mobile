import 'package:flutter/material.dart';

import '../call_icons.dart';
import 'call_surface.dart';

enum CallButtonTone { neutral, active, danger, accent }

/// One round control on the call bar. "On" states invert to white, so mute,
/// sharing and a raised hand all read without reading a label.
class CallRoundButton extends StatelessWidget {
  const CallRoundButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.tone = CallButtonTone.neutral,
    this.enabled = true,
    this.busy = false,
    this.compact = false,
  });

  final CallGlyph icon;
  final String label;
  final VoidCallback? onTap;
  final CallButtonTone tone;
  final bool enabled;
  final bool busy;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = CallColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    // "On" states invert against the theme's own onSurface/surface pair, so a
    // muted mic or a raised hand reads at a glance in light mode as well.
    final (background, foreground) = switch (tone) {
      CallButtonTone.neutral => (palette.tile, palette.onSurface),
      CallButtonTone.active => (palette.onSurface, palette.backdrop),
      CallButtonTone.danger => (palette.danger, scheme.onError),
      CallButtonTone.accent => (palette.accent, palette.onAccent),
    };
    final size = compact ? 44.0 : 58.0;
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
              width: size,
              height: size,
              child: busy
                  ? Padding(
                      padding: EdgeInsets.all(size / 3),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    )
                  : CallIcon(icon, color: foreground, size: compact ? 20 : 24),
            ),
          ),
        ),
      ),
    );
  }
}
