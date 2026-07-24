import 'package:flutter/material.dart';

import '../../../features/messages/chat_icon.dart';

/// One tab inside [NavPill] — Slack-style tall rounded selected chip.
class NavTabItem extends StatelessWidget {
  const NavTabItem({
    super.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final List<List<dynamic>> icon;
  final List<List<dynamic>> selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    final bg = selected
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.95)
        : Colors.transparent;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.fromLTRB(2, 6, 2, 6),
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            // Tall soft capsule like Slack "Home" chip — not a circle.
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Badge(
                isLabelVisible: badgeCount > 0,
                label: Text(badgeCount > 99 ? '99+' : '$badgeCount'),
                child: ChatIcon(
                  selected ? selectedIcon : icon,
                  size: 22,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
