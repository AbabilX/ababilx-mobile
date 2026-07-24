import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'nav_pill.dart';
import 'nav_tab_item.dart';

/// Left pill for contacts: My contacts | All contacts (same chrome as [NavPill]).
class ContactsScopePill extends StatelessWidget {
  const ContactsScopePill({
    super.key,
    required this.selectedIsMine,
    required this.mineLabel,
    required this.allLabel,
    required this.onSelectMine,
    required this.onSelectAll,
  });

  final bool selectedIsMine;
  final String mineLabel;
  final String allLabel;
  final VoidCallback onSelectMine;
  final VoidCallback onSelectAll;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: NavPill.height,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(NavPill.height / 2),
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
            icon: HugeIcons.strokeRoundedUser02,
            selectedIcon: HugeIcons.strokeRoundedUser03,
            label: mineLabel,
            selected: selectedIsMine,
            onTap: onSelectMine,
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
    );
  }
}
