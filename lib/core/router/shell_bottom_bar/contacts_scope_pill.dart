import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'nav_tab_item.dart';
import 'shell_pill_chrome.dart';
import 'shell_pill_metrics.dart';

/// Left pill for contacts: My | Add | All — height matches [ActionPill].
class ContactsScopePill extends StatelessWidget {
  const ContactsScopePill({
    super.key,
    required this.selectedIsMine,
    required this.addLabel,
    required this.mineLabel,
    required this.allLabel,
    required this.canAdd,
    required this.onAdd,
    required this.onSelectMine,
    required this.onSelectAll,
  });

  final bool selectedIsMine;
  final String addLabel;
  final String mineLabel;
  final String allLabel;
  final bool canAdd;
  final VoidCallback onAdd;
  final VoidCallback onSelectMine;
  final VoidCallback onSelectAll;

  @override
  Widget build(BuildContext context) {
    const h = ShellPillMetrics.height;

    return ShellPillChrome(
      child: SizedBox(
        height: h,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              NavTabItem(
                icon: HugeIcons.strokeRoundedUser02,
                selectedIcon: HugeIcons.strokeRoundedUser03,
                label: mineLabel,
                selected: selectedIsMine,
                onTap: onSelectMine,
              ),
              NavTabItem(
                icon: HugeIcons.strokeRoundedAdd01,
                selectedIcon: HugeIcons.strokeRoundedAdd01,
                label: addLabel,
                selected: false,
                onTap: canAdd ? onAdd : () {},
              ),
              NavTabItem(
                icon: HugeIcons.strokeRoundedUserGroup,
                selectedIcon: HugeIcons.strokeRoundedUserGroup,
                label: allLabel,
                selected: !selectedIsMine,
                onTap: onSelectAll,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
