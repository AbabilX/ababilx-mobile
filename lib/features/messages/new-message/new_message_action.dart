import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';

import '../chat_icon.dart';

class NewMessageAction extends StatelessWidget {
  const NewMessageAction({
    super.key,
    this.icon,
    this.hugeIcon,
    required this.label,
    required this.onTap,
  });

  final IconData? icon;

  /// Hugeicons path data; wins over [icon].
  final List<List<dynamic>>? hugeIcon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: colors.surfaceContainerHighest,
              foregroundColor: colors.onSurfaceVariant,
              child: hugeIcon != null
                  ? ChatIcon(
                      hugeIcon!,
                      size: 24,
                      color: colors.onSurfaceVariant,
                    )
                  : Icon(icon, size: 24),
            ),
            const SizedBox(width: 16),
            Text(label, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

/// The three ways in, above the people list. Phone search is paused
/// (numbers are never verified), so it has no row here.
class NewMessageActions extends ConsumerWidget {
  const NewMessageActions({
    super.key,
    required this.onGroup,
    required this.onUsername,
    required this.onFeed,
  });

  final VoidCallback onGroup;
  final VoidCallback onUsername;
  final VoidCallback onFeed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String tr(String key) => AppTranslations.translate(context, ref, key);
    return Column(
      children: [
        NewMessageAction(
          hugeIcon: HugeIcons.strokeRoundedUserGroup,
          label: tr('chat_new_group'),
          onTap: onGroup,
        ),
        NewMessageAction(
          hugeIcon: HugeIcons.strokeRoundedAt,
          label: tr('chat_find_by_username'),
          onTap: onUsername,
        ),
        // Last: a feed is set up once and then never again. Never gated —
        // a feed belongs to an account.
        NewMessageAction(
          hugeIcon: HugeIcons.strokeRoundedWebhook,
          label: tr('chat_new_webhook_feed'),
          onTap: onFeed,
        ),
      ],
    );
  }
}
