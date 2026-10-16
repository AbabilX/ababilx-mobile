import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/chat_icon.dart';
import '../../profile/delivery/delivery_only.dart';

/// The top of Local backup while delivery-only is on (server 0173): the
/// server keeps no lasting copy of the chats, so this backup is the only one,
/// and it lives on the same phone it protects. Said once, plainly, above the
/// switch — the one place someone deciding to turn it off will read it.
/// With backup off it turns into the warning itself. Draws nothing while
/// delivery-only is off, where the server still holds 120 days.
class LocalBackupDeliveryNotice extends ConsumerWidget {
  const LocalBackupDeliveryNotice({super.key, required this.backupOn});

  final bool backupOn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(deliveryOnlyProvider)) return const SizedBox.shrink();
    String t(String key) => AppTranslations.translate(context, ref, key);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tint = backupOn ? colors.primary : colors.error;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: ChatIcon(
              backupOn
                  ? HugeIcons.strokeRoundedSmartPhone01
                  : HugeIcons.strokeRoundedAlert02,
              size: 22,
              color: tint,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t(
                    backupOn
                        ? 'delivery_backup_notice_title'
                        : 'delivery_backup_off_warning',
                  ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: backupOn ? null : colors.error,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t('delivery_backup_notice_body'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
