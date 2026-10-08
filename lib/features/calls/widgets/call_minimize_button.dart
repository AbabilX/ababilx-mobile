import 'dart:ui';

import 'package:flutter/material.dart';

import '../group/call_icons.dart';

/// Chevron that leaves the call screen without hanging up.
///
/// Circular glass disc so it stays readable on both light and dark wallpapers.
class CallMinimizeButton extends StatelessWidget {
  const CallMinimizeButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  static const _size = 40.0;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: MaterialLocalizations.of(context).backButtonTooltip,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: _size,
            height: _size,
            child: ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: const ColoredBox(color: Colors.transparent),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                        width: 1,
                      ),
                    ),
                  ),
                  const Center(
                    child: CallIcon(
                      CallIcons.minimize,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
