import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/router/shell_bottom_bar/shell_pill_chrome.dart';
import '../../../core/router/shell_bottom_bar/shell_pill_metrics.dart';
import '../../messages/chat_icon.dart';

/// Floating frosted-pill Send/Receive tab bar for [LocalShareScreen].
class ShareTabBar extends StatelessWidget {
  const ShareTabBar({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return ShellPillChrome(
      child: SizedBox(
        height: ShellPillMetrics.height,
        child: Row(
          children: [
            _ShareTabItem(
              icon: HugeIcons.strokeRoundedArrowDataTransferHorizontal,
              label: 'Send',
              selected: selectedIndex == 0,
              onTap: () => onSelect(0),
            ),
            _ShareTabItem(
              icon: HugeIcons.strokeRoundedClock01,
              label: 'History',
              selected: selectedIndex == 1,
              onTap: () => onSelect(1),
            ),
            _ShareTabItem(
              icon: HugeIcons.strokeRoundedDownload04,
              label: 'Receive',
              selected: selectedIndex == 2,
              onTap: () => onSelect(2),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareTabItem extends StatelessWidget {
  const _ShareTabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final List<List<dynamic>> icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

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
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChatIcon(icon, size: 22, color: color),
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
