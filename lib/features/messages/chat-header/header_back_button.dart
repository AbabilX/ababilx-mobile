import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../shared/widgets/app_bar_back_button.dart';

/// Circular frosted back control for the chat header — same blur recipe as
/// [CallActionPill], circle instead of pill.
class HeaderBackButton extends StatelessWidget {
  const HeaderBackButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  static const _size = 40.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    final fill = colors.surface.withValues(alpha: dark ? 0.42 : 0.48);

    // NavigationToolbar forces the leading slot to the toolbar's full height,
    // so the circle's size is pinned OUTSIDE the clip. Sized inside it, the
    // ClipOval and its blur stretched to a 40x56 oval behind the 40dp fill —
    // a second, fainter ring around the button.
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Center(
        widthFactor: 1,
        child: SizedBox.square(
          dimension: _size,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: fill,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.outlineVariant.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Center(child: AppBarBackIcon()),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
