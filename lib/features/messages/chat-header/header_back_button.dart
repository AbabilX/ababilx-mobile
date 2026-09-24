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

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
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
                child: const SizedBox(
                  width: _size,
                  height: _size,
                  child: Center(child: AppBarBackIcon()),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
