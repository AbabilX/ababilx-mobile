import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../features/messages/chat_icon.dart';
import 'shell_pill_metrics.dart';

/// Circular trailing action beside the navigation capsule.
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

  static const double size = ShellPillMetrics.height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = enabled
        ? scheme.onSurfaceVariant
        : scheme.onSurfaceVariant.withValues(alpha: 0.35);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(child: ChatIcon(icon, size: 24, color: color)),
        ),
      ),
    );
  }
}

/// Home / contacts search — thin wrapper over [ActionPill].
class SearchPill extends StatelessWidget {
  const SearchPill({super.key, required this.onTap});

  final VoidCallback onTap;

  static const double size = ActionPill.size;

  @override
  Widget build(BuildContext context) {
    return ActionPill(icon: HugeIcons.strokeRoundedSearch01, onTap: onTap);
  }
}
