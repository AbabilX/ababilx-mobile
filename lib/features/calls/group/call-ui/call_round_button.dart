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
    final (background, foreground) = switch (tone) {
      CallButtonTone.neutral => (Colors.white.withValues(alpha: 0.12), Colors.white),
      CallButtonTone.active => (Colors.white, CallSurface.backdrop),
      CallButtonTone.danger => (CallSurface.danger, Colors.white),
      CallButtonTone.accent => (CallSurface.accent, const Color(0xFF0B1F14)),
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
