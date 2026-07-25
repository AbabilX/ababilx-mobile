import 'package:flutter/material.dart';

import '../../messages/chat_icon.dart';
import 'hub_items.dart';

/// Icon tile using theme containers — no hardcoded colors.
class CrmHubTile extends StatelessWidget {
  const CrmHubTile({
    super.key,
    required this.item,
    required this.label,
    required this.onTap,
  });

  final CrmHubItem item;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: ChatIcon(
                item.icon,
                size: 26,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}
