import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'nav_tab_item.dart';
import 'shell_pill_chrome.dart';
import 'shell_pill_metrics.dart';

/// Left floating nav — Messages | Wall | (CRM?) | Board.
class NavPill extends StatelessWidget {
  const NavPill({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.messagesLabel,
    required this.wallLabel,
    required this.crmLabel,
    required this.boardLabel,
    this.showCrm = false,
    this.unread = 0,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final String messagesLabel;
  final String wallLabel;
  final String crmLabel;
  final String boardLabel;
  final bool showCrm;
  final int unread;

  static const double height = ShellPillMetrics.height;

  @override
  Widget build(BuildContext context) {
    final boardIndex = showCrm ? 3 : 2;

    return ShellPillChrome(
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
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
                icon: HugeIcons.strokeRoundedNews,
                selectedIcon: HugeIcons.strokeRoundedNews,
                label: wallLabel,
                selected: selectedIndex == 1,
                onTap: () => onSelect(1),
              ),
              if (showCrm)
                NavTabItem(
                  icon: HugeIcons.strokeRoundedBriefcase01,
                  selectedIcon: HugeIcons.strokeRoundedBriefcase02,
                  label: crmLabel,
                  selected: selectedIndex == 2,
                  onTap: () => onSelect(2),
                ),
              NavTabItem(
                icon: HugeIcons.strokeRoundedTask01,
                selectedIcon: HugeIcons.strokeRoundedTask02,
                label: boardLabel,
                selected: selectedIndex == boardIndex,
                onTap: () => onSelect(boardIndex),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
