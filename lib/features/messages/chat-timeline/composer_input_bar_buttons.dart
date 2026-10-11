import 'package:flutter/material.dart';

import '../chat_icon.dart';

/// The flat icons that live inside the composer pill.
class PillIcon extends StatelessWidget {
  const PillIcon({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.height = 48,
    this.iconSize = 24,
  });

  final List<List<dynamic>> icon;
  final String tooltip;
  final VoidCallback onTap;

  /// The pill's own height, so the icon stays centred on a one-line field.
  final double height;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          width: 44,
          height: height,
          child: Center(
            child: ChatIcon(
              icon,
              size: iconSize,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// The one filled circle beside the pill: attach, then send.
class AccentCircle extends StatelessWidget {
  const AccentCircle({
    super.key,
    required this.sending,
    required this.label,
    required this.icon,
    required this.rotated,
    required this.onTap,
    this.size = 48,
  });

  final bool sending;
  final String label;
  final List<List<dynamic>> icon;

  /// "+" turns into a x while the attachment keyboard is up.
  final bool rotated;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: colors.primary,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: sending
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onPrimary,
                      ),
                    )
                  : AnimatedRotation(
                      turns: rotated ? 0.125 : 0,
                      duration: const Duration(milliseconds: 160),
                      child: ChatIcon(
                        icon,
                        size: size / 2,
                        color: colors.onPrimary,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
