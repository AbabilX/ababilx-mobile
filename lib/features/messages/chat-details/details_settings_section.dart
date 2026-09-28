import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../chat-lock/widgets/chat_lock_tile.dart';
import '../../private-chat/private_chat_tile.dart';
import '../chat_icon.dart';
import '../data/models/chat_models.dart';
import '../group-privacy/group_privacy_tile.dart';
import '../nickname/contact_nickname_provider.dart';
import '../nickname/nickname_sheet.dart';
import '../providers/chat_provider.dart';
import '../safety_number/safety_number_tile.dart';
import 'details_tile.dart';
import 'dm_privacy_sheet.dart';

/// The settings block under the header: nickname, safety number and privacy
/// for a DM, then wallpaper for every conversation. Pins and Mute live in the
/// header's button row.
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
      // DM only: private chat binds both people in it (server 0160). First,
      // because it changes more than anything below it.
      if (conversation.hasDmPeer && !conversation.isAccountDeleted)
        PrivateChatTile(conversationId: conversation.id),
      // DM only: ticks, notification text and privacy with this person share
      // one row that opens a sheet. The chat lock stays out: it is a gate on
      // the whole chat, not a privacy preference.
      if (conversation.isDm) DmPrivacyTile(conversation: conversation),
      if (conversation.isDm) ChatLockTile(conversationId: conversation.id),
      // Groups only: the group's own switch (server 0154), set by admins.
      if (conversation.isGroupConversation && !conversation.isWebhook)
        GroupPrivacyTile(conversation: conversation),
      // Groups only, admins only: what members may do (server 0157).
      if (conversation.type == 'group' && conversation.iAmAdmin)
        DetailsTile(
          icon: const ChatIcon(HugeIcons.strokeRoundedKey01),
          title: AppTranslations.translate(context, ref, 'group_perm_tile'),
          value: _permsSummary(conversation),
          onTap: () => context.push('/messages/${conversation.id}/permissions'),
        ),
      DetailsTile(
        icon: const ChatIcon(HugeIcons.strokeRoundedPaintBoard),
        title: 'Chat color & wallpaper',
        onTap: () => context.push('/messages/${conversation.id}/wallpaper'),
      ),
    ],
  );
}

/// "9/11" — how many of the member permissions the group leaves on.
String _permsSummary(ChatConversation conversation) {
  final set = (conversation.defaultPermissions ?? GroupMemberPerms.all)
      .toJson();
  final on = set.values.where((v) => v == true).length;
  return '$on/${set.length}';
}
