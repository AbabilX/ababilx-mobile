import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/widgets/app_toast.dart';
import '../chat-details/details_tile.dart';
import '../chat_icon.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'group_privacy_api.dart';

/// "Group privacy" on a group's details screen (server 0154). Admins get the
/// switch; everyone else sees the row only while it is on, so they know why
/// Forward and Save are missing.
class GroupPrivacyTile extends ConsumerStatefulWidget {
  const GroupPrivacyTile({super.key, required this.conversation});

  final ChatConversation conversation;

  @override
  ConsumerState<GroupPrivacyTile> createState() => _GroupPrivacyTileState();
}

class _GroupPrivacyTileState extends ConsumerState<GroupPrivacyTile> {
  bool _busy = false;

  Future<void> _set(bool on) async {
    setState(() => _busy = true);
    try {
      final updated = await putGroupPrivacy(
        ref.read(apiClientProvider),
        widget.conversation.id,
        enabled: on,
      );
      ref.read(chatProvider.notifier).upsertChannel(updated);
    } catch (_) {
      if (mounted) {
        showAppToast(
          context,
          AppTranslations.translate(context, ref, 'group_privacy_failed'),
          isError: true,
        );
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final conversation = widget.conversation;
    final on = conversation.groupPrivacy;
    final admin = conversation.iAmAdmin;
    if (!admin && !on) return const SizedBox.shrink();
    return DetailsTile(
      icon: const ChatIcon(HugeIcons.strokeRoundedSquareLock02),
      title: t('group_privacy_tile'),
      value: [
        t(on ? 'group_privacy_on' : 'group_privacy_off'),
        if (!admin) t('group_privacy_admin_hint'),
      ].join('\n'),
      onTap: admin && !_busy ? () => _set(!on) : null,
      trailing: admin
          ? Switch(value: on, onChanged: _busy ? null : _set)
          : null,
    );
  }
}
