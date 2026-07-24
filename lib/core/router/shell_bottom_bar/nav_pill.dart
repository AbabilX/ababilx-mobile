import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'nav_tab_item.dart';

/// Left floating nav — Slack stadium pill (fully rounded ends).
class NavPill extends StatelessWidget {
  const NavPill({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.messagesLabel,
    required this.profileLabel,
    this.unread = 0,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final String messagesLabel;
  final String profileLabel;
  final int unread;

  static const double height = 64;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(height / 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: scheme.brightness == Brightness.dark ? 0.35 : 0.12,
            ),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          NavTabItem(
            icon: HugeIcons.strokeRoundedBubbleChat,
            selectedIcon: HugeIcons.strokeRoundedMessage01,
            label: messagesLabel,
            selected: selectedIndex == 0,
            badgeCount: unread,
            onTap: () => onSelect(0),
          ),
          NavTabItem(
            icon: HugeIcons.strokeRoundedUser02,
            selectedIcon: HugeIcons.strokeRoundedUser03,
            label: profileLabel,
            selected: selectedIndex == 1,
            onTap: () => onSelect(1),
          ),
        ],
      ),
    );
  }
}
