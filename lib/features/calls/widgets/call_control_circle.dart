import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A round call control, sized by the space it is given rather than by a
/// constant.
///
/// Material 3 Expressive's own media controls are circles far larger than the
/// 56dp a toolbar icon gets, because on a screen whose whole purpose is four
/// choices, the choices should be the biggest thing on it. Dropped into an
/// [Expanded] the circle grows to that column's width (capped, so a tablet
/// does not get a dinner plate), which is how the deck reaches both edges.
///
/// Press morphs the circle towards a squircle instead of only dimming it:
/// Expressive's shape-change feedback, and it survives a thumb covering the
/// button in a way a ripple does not.
class CallControlCircle extends StatefulWidget {
  const CallControlCircle({
    super.key,
    required this.icon,
    required this.onPressed,
    this.label,
    this.selected = false,
    this.background,
    this.foreground,
    this.maxSize = 92,
    this.fixedSize,
    this.iconScale = 0.42,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? label;
  final bool selected;

  /// Set only where the colour means something by itself — End is the error
  /// role in both states, so it never takes the selected fill.
  final Color? background;
  final Color? foreground;

  /// Cap for the grow-to-fit case; [fixedSize] opts out of growing at all.
  final double maxSize;
  final double? fixedSize;
  final double iconScale;

  @override
  State<CallControlCircle> createState() => _CallControlCircleState();
}

class _CallControlCircleState extends State<CallControlCircle> {
  /// Held here, not in an ink highlight: the squeeze animates the container's
  /// own shape, which the ink layer above it cannot reach.
  bool _down = false;

  static const _morph = Duration(milliseconds: 170);

  void _setDown(bool down) {
    if (_down == down) return;
    setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = widget.onPressed != null;
    final background =
        widget.background ??
        (widget.selected ? colors.primary : colors.surfaceContainerHighest);
    final foreground =
        widget.foreground ??
        (widget.selected ? colors.onPrimary : colors.onSurfaceVariant);

    final button = AnimatedOpacity(
      duration: _morph,
      opacity: enabled ? 1 : 0.4,
      child: AnimatedScale(
        duration: _morph,
        curve: Curves.easeOut,
        scale: _down ? 0.94 : 1,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The radius is a fraction of the real diameter, so the squircle
            // looks the same on a 72dp toggle and a 96dp End.
            final size = constraints.maxWidth;
            return AnimatedContainer(
              duration: _morph,
              curve: Curves.easeOutCubic,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(
                  _down ? size * 0.32 : size / 2,
                ),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: enabled
                      ? () {
                          HapticFeedback.selectionClick();
                          widget.onPressed!();
                        }
                      : null,
                  onTapDown: enabled ? (_) => _setDown(true) : null,
                  onTapUp: enabled ? (_) => _setDown(false) : null,
                  onTapCancel: enabled ? () => _setDown(false) : null,
                  child: Icon(
                    widget.icon,
                    size: size * widget.iconScale,
                    color: foreground,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      toggled: widget.background == null ? widget.selected : null,
      label: widget.label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: widget.fixedSize ?? widget.maxSize,
              ),
              child: SizedBox(
                width: widget.fixedSize,
                child: AspectRatio(aspectRatio: 1, child: button),
              ),
            ),
          ),
          if (widget.label != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.label!,
              textAlign: TextAlign.center,
              // Two lines, because four labels across a phone is narrow and
              // "Take over" must not ellipsise into "Take…".
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
