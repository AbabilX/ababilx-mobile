import 'package:flutter/material.dart';

import 'contacts_scope_pill.dart';
import 'nav_pill.dart';
import 'organizations_action_pill.dart';
import 'search_pill.dart';
import 'shell_pill_metrics.dart';

enum ShellBottomBarMode { home, contacts, organizations }

/// Floating pills — home: nav+search; contacts: [My|Add|All] + **contact** search.
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

  final int selectedIndex;
  final ValueChanged<int>? onSelect;

  /// Home-only: messages/wall search.
  final VoidCallback? onSearch;
  final String messagesLabel;
  final String wallLabel;
  final String crmLabel;
  final String profileLabel;
  final bool showCrm;
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
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
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
            ),
            SizedBox(width: ShellPillMetrics.gap),
            // Separate callbacks so contacts never accidentally hits chat/wall search.
            SizedBox(
              width: ShellPillMetrics.height,
              height: ShellPillMetrics.height,
              child: isContacts || isOrganizations
                  ? SearchPill(onTap: onContactsSearch ?? () {})
                  : SearchPill(onTap: onSearch ?? () {}),
            ),
          ],
        ),
      ),
    );
  }
}
