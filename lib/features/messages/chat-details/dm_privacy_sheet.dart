import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../dm-settings/notification_text/hide_notification_text.dart';
import '../../dm-settings/receipts/hide_ticks_tile.dart';
import '../../privacy-mode/people/privacy_person_tile.dart';
import '../chat_icon.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'details_tile.dart';

/// One row on a DM's details screen that opens the per-chat privacy switches
/// together — ticks, notification text and privacy with this person — instead
/// of three rows each taking a line of the screen.
class DmPrivacyTile extends ConsumerWidget {
  const DmPrivacyTile({super.key, required this.conversation});

  final ChatConversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) => DetailsTile(
    icon: const ChatIcon(HugeIcons.strokeRoundedShield01),
    title: AppTranslations.translate(context, ref, 'dm_privacy_settings'),
    onTap: () => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _DmPrivacySheet(conversation: conversation),
    ),
  );
}

class _DmPrivacySheet extends ConsumerWidget {
  const _DmPrivacySheet({required this.conversation});

  final ChatConversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPeer = conversation.hasDmPeer && !conversation.isAccountDeleted;
    final currentUserId = ref.read(chatProvider).currentUserId;
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                AppTranslations.translate(context, ref, 'dm_privacy_settings'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (hasPeer) HideTicksTile(conversationId: conversation.id),
            HideNotificationTextTile(conversationId: conversation.id),
            if (hasPeer)
              PrivacyPersonTile(
                userId: conversation.peerUserId!,
                displayName: conversation.displayTitle(currentUserId),
                name: conversation.peerUserName ?? '',
                avatarUrl: conversation.peerUserAvatar ?? '',
              ),
          ],
        ),
      ),
    );
  }
}
