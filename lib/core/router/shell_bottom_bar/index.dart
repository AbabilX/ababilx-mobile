import 'package:flutter/material.dart';

import 'nav_pill.dart';
import 'search_pill.dart';

/// Slack-style floating pills: left nav + right search.
class ShellBottomBar extends StatelessWidget {
  const ShellBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.onSearch,
    required this.messagesLabel,
    required this.wallLabel,
    required this.crmLabel,
    required this.profileLabel,
    this.unread = 0,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onSearch;
  final String messagesLabel;
  final String wallLabel;
  final String crmLabel;
  final String profileLabel;
  final int unread;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: NavPill(
                selectedIndex: selectedIndex,
                onSelect: onSelect,
                messagesLabel: messagesLabel,
                wallLabel: wallLabel,
                crmLabel: crmLabel,
                profileLabel: profileLabel,
                unread: unread,
              ),
            ),
            const SizedBox(width: 10),
            SearchPill(onTap: onSearch),
          ],
        ),
      ),
    );
  }
}
