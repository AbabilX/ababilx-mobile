import 'package:flutter/material.dart';

import '../../messages/chat_icon.dart';
import 'hub_items.dart';

/// Colored rounded square + label under it (WeCom-style tile).
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
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: item.color,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: ChatIcon(item.icon, size: 26, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w500,
                color: colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
