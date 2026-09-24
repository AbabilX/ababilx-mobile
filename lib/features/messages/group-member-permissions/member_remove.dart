import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'group_member_tags_provider.dart';

/// Asks, then removes [member] from the group. Answers whether they went.
Future<bool> confirmRemoveMember(
  BuildContext context,
  WidgetRef ref, {
  required String conversationId,
  required ChatMember member,
}) async {
  String t(String key) => AppTranslations.translate(context, ref, key);
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(t('group_member_remove')),
      content: Text(
        t('group_member_remove_confirm').replaceAll('{name}', member.name),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: Text(t('cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialog, true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(dialog).colorScheme.error,
          ),
          child: Text(t('group_member_remove_action')),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  try {
    await ref
        .read(chatProvider.notifier)
        .removeGroupMember(conversationId, member.userId);
    ref.read(groupRosterRevisionProvider(conversationId).notifier).state++;
    return true;
  } catch (_) {
    if (context.mounted) {
      showAppToast(context, t('group_member_remove_failed'), isError: true);
    }
    return false;
  }
}
