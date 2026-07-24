import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'contacts_scope_pill.dart';
import 'nav_pill.dart';
import 'search_pill.dart';

enum ShellBottomBarMode { home, contacts }

/// Floating pills bar — home nav+search, or contacts My/All + add.
class ShellBottomBar extends StatelessWidget {
  const ShellBottomBar({
    super.key,
    this.mode = ShellBottomBarMode.home,
    // Home
    this.selectedIndex = 0,
    this.onSelect,
    this.onSearch,
    this.messagesLabel = '',
    this.wallLabel = '',
    this.crmLabel = '',
    this.profileLabel = '',
    this.showCrm = false,
    this.unread = 0,
    // Contacts
    this.contactsMineSelected = true,
    this.mineLabel = '',
    this.allLabel = '',
    this.onSelectMine,
    this.onSelectAll,
    this.onAdd,
    this.canAdd = false,
  });

  final ShellBottomBarMode mode;

  final int selectedIndex;
  final ValueChanged<int>? onSelect;
  final VoidCallback? onSearch;
  final String messagesLabel;
  final String wallLabel;
  final String crmLabel;
  final String profileLabel;
  final bool showCrm;
  final int unread;

  final bool contactsMineSelected;
  final String mineLabel;
  final String allLabel;
  final VoidCallback? onSelectMine;
  final VoidCallback? onSelectAll;
  final VoidCallback? onAdd;
  final bool canAdd;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: mode == ShellBottomBarMode.contacts
                  ? ContactsScopePill(
                      selectedIsMine: contactsMineSelected,
                      mineLabel: mineLabel,
                      allLabel: allLabel,
                      onSelectMine: onSelectMine ?? () {},
                      onSelectAll: onSelectAll ?? () {},
                    )
                  : NavPill(
                      selectedIndex: selectedIndex,
                      onSelect: onSelect ?? (_) {},
                      messagesLabel: messagesLabel,
                      wallLabel: wallLabel,
                      crmLabel: crmLabel,
                      profileLabel: profileLabel,
                      showCrm: showCrm,
                      unread: unread,
                    ),
            ),
            const SizedBox(width: 10),
            if (mode == ShellBottomBarMode.contacts)
              ActionPill(
                icon: HugeIcons.strokeRoundedAdd01,
                enabled: canAdd,
                onTap: onAdd,
              )
            else
              SearchPill(onTap: onSearch ?? () {}),
          ],
        ),
      ),
    );
  }
}
