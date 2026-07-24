import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';

class ChatListHeader extends StatelessWidget {
  const ChatListHeader({
    super.key,
    required this.onSearch,
    required this.onCompose,
  });

  final VoidCallback onSearch;
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Direct messages',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Search',
            onPressed: onSearch,
            icon: const ChatIcon(HugeIcons.strokeRoundedSearch01),
          ),
          IconButton(
            tooltip: 'Compose',
            onPressed: onCompose,
            icon: const ChatIcon(HugeIcons.strokeRoundedPencilEdit01),
          ),
        ],
      ),
    );
  }
}
