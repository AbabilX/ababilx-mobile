import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';

/// "Unpin all" as a floating pill, bottom centre of the Pins page: icon and
/// short label in the error colour on the header capsules' fill, lifted a
/// little so it reads over the bubbles; a spinner while the unpins run
/// ([onPressed] null).
class UnpinAllFab extends StatelessWidget {
  const UnpinAllFab({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHigh,
      shape: const StadiumBorder(),
      elevation: 4,
      shadowColor: Colors.black54,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: onPressed == null
                ? const Center(
                    widthFactor: 1,
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ChatIcon(
                        HugeIcons.strokeRoundedPinOff,
                        size: 20,
                        color: colors.error,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.error,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
