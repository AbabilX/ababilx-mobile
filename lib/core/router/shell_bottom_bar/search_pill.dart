import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../features/messages/chat_icon.dart';

/// Right circular action — same size as home search pill.
class ActionPill extends StatelessWidget {
  const ActionPill({
    super.key,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  final List<List<dynamic>> icon;
  final VoidCallback? onTap;
  final bool enabled;

  static const double size = 64;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = enabled
        ? scheme.onSurfaceVariant
        : scheme.onSurfaceVariant.withValues(alpha: 0.35);

    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 8,
      shadowColor: Colors.black.withValues(
        alpha: scheme.brightness == Brightness.dark ? 0.4 : 0.14,
      ),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: ChatIcon(icon, size: 24, color: color),
          ),
        ),
      ),
    );
  }
}

/// Home search — thin wrapper over [ActionPill].
class SearchPill extends StatelessWidget {
  const SearchPill({super.key, required this.onTap});

  final VoidCallback onTap;

  static const double size = ActionPill.size;

  @override
  Widget build(BuildContext context) {
    return ActionPill(
      icon: HugeIcons.strokeRoundedSearch01,
      onTap: onTap,
    );
  }
}
