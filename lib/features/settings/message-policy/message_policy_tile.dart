import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../settings-hub/settings_row.dart';
import 'message_policy_provider.dart';

/// Settings → Account → "Who can message me", one tap from the account
/// page (moved off Discovery 2026-10-24 for quicker reach). Shows the current
/// choice; tapping opens a bottom sheet with the two options.
class MessagePolicyTile extends ConsumerWidget {
  const MessagePolicyTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final policy = ref.watch(messagePolicyProvider);
    return SettingsRow(
      icon: HugeIcons.strokeRoundedMessageLock01,
      title: t('message_policy_title'),
      subtitle: t(_labelKey(policy)),
      onTap: () => showMessagePolicySheet(context, ref),
    );
  }
}

String _labelKey(MessagePolicy p) => p == MessagePolicy.connections
    ? 'message_policy_connections'
    : 'message_policy_requests';

String _hintKey(MessagePolicy p) => p == MessagePolicy.connections
    ? 'message_policy_connections_hint'
    : 'message_policy_requests_hint';

/// Two options, one tap each; the sheet closes on a pick and saves.
Future<void> showMessagePolicySheet(BuildContext context, WidgetRef ref) async {
  String t(String key) => AppTranslations.translate(context, ref, key);
  final current = ref.read(messagePolicyProvider);
  final picked = await showModalBottomSheet<MessagePolicy>(
    context: context,
    showDragHandle: true,
    builder: (sheet) {
      final theme = Theme.of(sheet);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                t('message_policy_title'),
                style: theme.textTheme.titleMedium,
              ),
            ),
            for (final option in MessagePolicy.values)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: HugeIcon(
                  icon: option == current
                      ? HugeIcons.strokeRoundedCheckmarkCircle02
                      : HugeIcons.strokeRoundedCircle,
                  color: option == current
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(t(_labelKey(option))),
                subtitle: Text(
                  t(_hintKey(option)),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                onTap: () => Navigator.of(sheet).pop(option),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
  if (picked == null || picked == current) return;
  final failed = t('message_policy_save_failed');
  final ok = await ref.read(messagePolicyProvider.notifier).set(picked);
  if (!ok && context.mounted) showAppToast(context, failed, isError: true);
}
