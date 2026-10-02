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
  static const double gap = 6;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Ordinary text colours; the surface tone behind the chosen tab is the
    // bar's sliding indicator (nav_pill.dart).
    final color = selected ? scheme.onSurface : scheme.onSurfaceVariant;
    // Concentric with the capsule: its radius is half the pill height, so the
    // chosen tab, inset by [gap] on every side, takes that radius minus the
    // gap — the two curves then run parallel instead of clashing at the ends.
    final radius = BorderRadius.circular(ShellPillMetrics.height / 2 - gap);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          // The chosen-tab background is the bar's sliding indicator, drawn
          // behind the row; this only keeps the same inset.
          padding: const EdgeInsets.all(gap),
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
