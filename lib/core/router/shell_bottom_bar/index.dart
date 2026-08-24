import 'package:flutter/material.dart';

import 'contacts_scope_pill.dart';
import 'nav_pill.dart';
import 'organizations_action_pill.dart';
import 'search_pill.dart';
import 'shell_pill_metrics.dart';
import 'shell_tabs.dart';

enum ShellBottomBarMode { home, contacts, organizations }

/// Edge-to-edge flat bottom navigation and context actions.
class ShellBottomBar extends StatelessWidget {
  const ShellBottomBar({
    super.key,
    this.mode = ShellBottomBarMode.home,
    // Home
    this.tabs = const [],
    this.selectedIndex = 0,
    this.onSelect,
    this.onSearch,
    this.labelOf,
    this.unread = 0,
    // Contacts
    this.contactsMineSelected = true,
    this.addLabel = '',
    this.mineLabel = '',
    this.allLabel = '',
    this.onSelectMine,
    this.onSelectAll,
    this.onAdd,
    this.canAdd = false,

    /// Contacts route only — must open contact search, never chat/wall.
    this.onContactsSearch,
    this.organizationsLabel = '',
  });

  final ShellBottomBarMode mode;

  /// Home-only: the destinations this account actually has.
  final List<ShellTab> tabs;
  final int selectedIndex;
  final ValueChanged<int>? onSelect;

  /// Home-only: messages/wall search.
  final VoidCallback? onSearch;

  /// Home-only: resolves a tab's translated label.
  final String Function(ShellTab tab)? labelOf;
  final int unread;

  final bool contactsMineSelected;
  final String addLabel;
  final String mineLabel;
  final String allLabel;
  final VoidCallback? onSelectMine;
  final VoidCallback? onSelectAll;
  final VoidCallback? onAdd;
  final bool canAdd;
  final VoidCallback? onContactsSearch;
  final String organizationsLabel;

  @override
  Widget build(BuildContext context) {
    final isContacts = mode == ShellBottomBarMode.contacts;
    final isOrganizations = mode == ShellBottomBarMode.organizations;

    return SafeArea(
      top: false,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: Container(
          height: ShellPillMetrics.height,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: SizedBox(
                  height: ShellPillMetrics.height,
                  child: isOrganizations
                      ? OrganizationsActionPill(
                          organizationsLabel: organizationsLabel,
                          addLabel: addLabel,
                          canAdd: canAdd,
                          onAdd: onAdd ?? () {},
                        )
                      : isContacts
                      ? ContactsScopePill(
                          selectedIsMine: contactsMineSelected,
                          addLabel: addLabel,
                          mineLabel: mineLabel,
                          allLabel: allLabel,
                          canAdd: canAdd,
                          onAdd: onAdd ?? () {},
                          onSelectMine: onSelectMine ?? () {},
                          onSelectAll: onSelectAll ?? () {},
                        )
                      : NavPill(
                          tabs: tabs,
                          selectedIndex: selectedIndex,
                          onSelect: onSelect ?? (_) {},
                          labelOf: labelOf ?? (t) => t.labelKey,
                          unread: unread,
                        ),
                ),
              ),
              if (isContacts || isOrganizations) ...[
                const VerticalDivider(width: 1),
                SizedBox(
                  width: ShellPillMetrics.height,
                  height: ShellPillMetrics.height,
                  child: SearchPill(onTap: onContactsSearch ?? () {}),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
