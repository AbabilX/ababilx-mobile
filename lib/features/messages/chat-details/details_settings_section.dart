import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../privacy-mode/people/privacy_person_tile.dart';
import '../chat_icon.dart';
import '../data/models/chat_models.dart';
import '../nickname/contact_nickname_provider.dart';
import '../nickname/nickname_sheet.dart';
import '../providers/chat_provider.dart';
import '../safety_number/safety_number_tile.dart';
import 'details_tile.dart';

/// The settings block under the header: nickname, safety number and privacy
/// for a DM, then wallpaper and notifications for every conversation.
class DetailsSettingsSection extends ConsumerWidget {
  const DetailsSettingsSection({super.key, required this.conversation});

  final ChatConversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // DM only: a nickname renames a person, and a group is not one. It sits
      // first because it is the fix for a name you cannot read.
      if (conversation.hasDmPeer)
        DetailsTile(
          icon: const ChatIcon(HugeIcons.strokeRoundedUserEdit01),
          title: 'Nickname',
          value:
              ref
                  .watch(contactNicknamesProvider)
                  .forUser(conversation.peerUserId) ??
              'None',
          onTap: () => showNicknameSheet(
            context,
            ref,
            userId: conversation.peerUserId!,
            profileName: conversation.peerUserName,
          ),
        ),
      // DM only: a safety number is a comparison between two identities, and a
      // group has no single peer identity to compare against. A deleted account
      // has no key left to compare.
      if (conversation.hasDmPeer && !conversation.isAccountDeleted)
        SafetyNumberTile(
          peerUserId: conversation.peerUserId!,
          peerName: conversation.displayTitle(
            ref.read(chatProvider).currentUserId,
          ),
        ),
      // DM only: privacy mode never reaches past one person (server 0153).
      // Not for a deleted account — there is nobody left to hide from.
      if (conversation.hasDmPeer && !conversation.isAccountDeleted)
        PrivacyPersonTile(
          userId: conversation.peerUserId!,
          displayName: conversation.displayTitle(
            ref.read(chatProvider).currentUserId,
          ),
          name: conversation.peerUserName ?? '',
          avatarUrl: conversation.peerUserAvatar ?? '',
        ),
      DetailsTile(
        icon: const ChatIcon(HugeIcons.strokeRoundedPaintBoard),
        title: 'Chat color & wallpaper',
        onTap: () => context.push('/messages/${conversation.id}/wallpaper'),
      ),
      DetailsTile(
        icon: ChatIcon(
          conversation.muted
              ? HugeIcons.strokeRoundedNotificationOff01
              : HugeIcons.strokeRoundedNotification01,
        ),
        title: 'Sounds & notifications',
        value: conversation.muted ? 'Muted' : 'All messages',
        trailing: Switch(
          value: !conversation.muted,
          onChanged: (on) => ref
              .read(chatProvider.notifier)
              .muteConversation(conversation.id, !on),
        ),
      ),
    ],
  );
}
