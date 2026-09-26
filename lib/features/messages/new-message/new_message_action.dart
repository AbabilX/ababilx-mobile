import 'package:flutter/material.dart';

import '../chat_icon.dart';

class NewMessageAction extends StatelessWidget {
  const NewMessageAction({
    super.key,
    this.icon,
    this.hugeIcon,
    required this.label,
    required this.onTap,
  });

  final IconData? icon;

  /// Hugeicons path data; wins over [icon].
  final List<List<dynamic>>? hugeIcon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: colors.surfaceContainerHighest,
              foregroundColor: colors.onSurfaceVariant,
              child: hugeIcon != null
                  ? ChatIcon(
                      hugeIcon!,
                      size: 24,
                      color: colors.onSurfaceVariant,
                    )
                  : Icon(icon, size: 24),
            ),
            const SizedBox(width: 16),
            Text(label, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
