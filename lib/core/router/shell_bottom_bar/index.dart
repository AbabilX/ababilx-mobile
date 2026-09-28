import 'package:flutter/material.dart';

import 'contacts_scope_pill.dart';
import 'nav_pill.dart';
import 'organizations_action_pill.dart';
import 'search_pill.dart';
import 'shell_pill_chrome.dart';
import 'shell_pill_metrics.dart';
import 'shell_tabs.dart';

enum ShellBottomBarMode { home, contacts, organizations }

/// Floating capsule navigation, with CRM-only search when no app-bar search exists.
class ShellBottomBar extends StatelessWidget {
  const ShellBottomBar({
    super.key,
    this.mode = ShellBottomBarMode.home,
    // Home
    this.tabs = const [],
    this.selectedIndex = 0,
    this.onSelect,
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: _fitHome(
                home: !isContacts && !isOrganizations,
                child: ShellPillChrome(
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
                            labelOf: labelOf ?? (tab) => tab.labelKey,
                            unread: unread,
                          ),
                  ),
                ),
              ),
            ),
            if (isContacts || isOrganizations) ...[
              const SizedBox(width: 10),
              ShellPillChrome(
                shape: BoxShape.circle,
                child: SearchPill(onTap: onContactsSearch ?? () {}),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Home bar only: as wide as its tabs ask for (never under
  /// [NavPill.minWidth]), centred, so fewer tabs mean a narrower capsule. Never
  /// wider than the room the screen leaves it.
  Widget _fitHome({required bool home, required Widget child}) {
    if (!home || tabs.isEmpty) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: NavPill.widthFor(tabs.length)),
        child: child,
      ),
    );
  }
}
