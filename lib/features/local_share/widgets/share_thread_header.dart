import 'package:flutter/material.dart';

import 'package:hugeicons/hugeicons.dart';

import 'share_device_avatar.dart';
import '../../../shared/widgets/flat_capsule_header.dart';

/// A thread's header: a Back capsule, the device's picture, name and whether
/// it is in range written flat in the middle, the thread's menu capsule.
class ShareThreadHeader extends StatelessWidget {
  const ShareThreadHeader({
    super.key,
    required this.name,
    required this.status,
    required this.deviceType,
    required this.userId,
    required this.nearby,
    required this.menuLabel,
    this.onMenu,
  });

  final String name;
  final String status;
  final String deviceType;
  final String? userId;
  final bool nearby;
  final String menuLabel;

  /// Null until the device is known: there is nothing to block or forget.
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return FlatCapsuleHeader(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShareDeviceAvatar(
            deviceType: deviceType,
            userId: userId,
            size: 36,
            nearby: nearby,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    color: nearby ? colors.primary : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      action: onMenu == null
          ? null
          : FlatHeaderAction(
              icon: HugeIcons.strokeRoundedMoreVertical,
              label: menuLabel,
              onPressed: onMenu!,
            ),
    );
  }
}
