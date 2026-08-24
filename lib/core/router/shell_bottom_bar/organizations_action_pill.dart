import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'nav_tab_item.dart';
import 'shell_pill_metrics.dart';

class OrganizationsActionPill extends StatelessWidget {
  const OrganizationsActionPill({
    super.key,
    required this.organizationsLabel,
    required this.addLabel,
    required this.canAdd,
    required this.onAdd,
  });

  final String organizationsLabel;
  final String addLabel;
  final bool canAdd;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ShellPillMetrics.height,
      child: Row(
        children: [
          NavTabItem(
            icon: HugeIcons.strokeRoundedBuilding03,
            selectedIcon: HugeIcons.strokeRoundedBuilding03,
            label: organizationsLabel,
            selected: true,
            onTap: () {},
          ),
          NavTabItem(
            icon: HugeIcons.strokeRoundedAdd01,
            selectedIcon: HugeIcons.strokeRoundedAdd01,
            label: addLabel,
            selected: false,
            onTap: canAdd ? onAdd : () {},
          ),
        ],
      ),
    );
  }
}
