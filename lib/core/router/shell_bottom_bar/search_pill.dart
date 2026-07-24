import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../features/messages/chat_icon.dart';

/// Right search control — full circle, same height as [NavPill].
class SearchPill extends StatelessWidget {
  const SearchPill({super.key, required this.onTap});

  final VoidCallback onTap;

  static const double size = 64;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 8,
      shadowColor: Colors.black.withValues(
        alpha: scheme.brightness == Brightness.dark ? 0.4 : 0.14,
      ),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: ChatIcon(
              HugeIcons.strokeRoundedSearch01,
              size: 24,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
