import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'nav_tab_item.dart';

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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
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
