import 'package:flutter/material.dart';

import '../../../features/messages/chat_icon.dart';
import 'shell_pill_metrics.dart';

/// One navigation destination inside the shared capsule.
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

  /// Space between the capsule's edge and the chosen tab's background.
  static const double _gap = 6;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Ordinary text colours, and the neutral surface tone behind the chosen
    // tab — the same quiet square the details and Talks buttons wear.
    final color = selected ? scheme.onSurface : scheme.onSurfaceVariant;
    // Concentric with the capsule: its radius is half the pill height, so the
    // chosen tab, inset by [_gap] on every side, takes that radius minus the
    // gap — the two curves then run parallel instead of clashing at the ends.
    final radius = BorderRadius.circular(ShellPillMetrics.height / 2 - _gap);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(_gap),
          decoration: BoxDecoration(
            color: selected ? scheme.surfaceContainerHigh : Colors.transparent,
            borderRadius: radius,
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
