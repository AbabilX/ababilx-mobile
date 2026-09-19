import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'call_top_bar.dart' show callTextShadow;

/// Frosted glass circle used by the 1:1 call control deck.
///
/// Translucent dark fill + hairline white border so icons stay readable on
/// both the light and dark call wallpapers (and over remote video).
class CallGlassCircle extends StatefulWidget {
  const CallGlassCircle({
    super.key,
    required this.icon,
    required this.onPressed,
    this.label,
    this.selected = false,
    this.diameter,
    this.iconSize,
    this.labelFontSize,
    this.background,
    this.foreground,
    this.glow = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? label;
  final bool selected;
  final double? diameter;
  final double? iconSize;
  final double? labelFontSize;

  /// Solid hang-up red — skips the glass treatment.
  final Color? background;
  final Color? foreground;
  final bool glow;

  @override
  State<CallGlassCircle> createState() => _CallGlassCircleState();
}

class _CallGlassCircleState extends State<CallGlassCircle> {
  bool _down = false;

  static const _morph = Duration(milliseconds: 160);

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final size = widget.diameter ?? 64;
    final iconSize = widget.iconSize ?? size * 0.4;
    final solid = widget.background != null;
    final bg =
        widget.background ??
        Colors.black.withValues(alpha: widget.selected ? 0.42 : 0.26);
    final fg = widget.foreground ?? Colors.white;

    final circle = AnimatedOpacity(
      duration: _morph,
      opacity: enabled ? 1 : 0.4,
      child: AnimatedScale(
        duration: _morph,
        curve: Curves.easeOut,
        scale: _down ? 0.94 : 1,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: widget.glow
                ? [
                    BoxShadow(
                      color: (widget.background ?? Colors.red).withValues(
                        alpha: 0.35,
                      ),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: ClipOval(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (!solid)
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: const ColoredBox(color: Colors.transparent),
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: bg,
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: solid ? 0.12 : 0.22,
                      ),
                      width: 1,
                    ),
                  ),
                ),
                Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: enabled
                        ? () {
                            HapticFeedback.selectionClick();
                            widget.onPressed!();
                          }
                        : null,
                    onTapDown: enabled ? (_) => setState(() => _down = true) : null,
                    onTapUp: enabled
                        ? (_) => setState(() => _down = false)
                        : null,
                    onTapCancel: enabled
                        ? () => setState(() => _down = false)
                        : null,
                    child: Center(
                      child: Icon(widget.icon, size: iconSize, color: fg),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      toggled: solid ? null : widget.selected,
      label: widget.label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          circle,
          if (widget.label != null) ...[
            SizedBox(height: (size * 0.14).clamp(10.0, 16.0)),
            Text(
              widget.label!,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: widget.labelFontSize ?? 12,
                fontWeight: FontWeight.w500,
                height: 1.15,
                shadows: callTextShadow,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
