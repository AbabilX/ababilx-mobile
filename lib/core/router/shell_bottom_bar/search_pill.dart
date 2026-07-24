import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../features/messages/chat_icon.dart';

class SearchPill extends StatelessWidget {
  const SearchPill({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerHigh,
      shape: const StadiumBorder(),
      elevation: 8,
      shadowColor: Colors.black.withValues(
        alpha: scheme.brightness == Brightness.dark ? 0.4 : 0.14,
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: SizedBox(
          width: 56,
          height: 64,
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
