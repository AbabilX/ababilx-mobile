import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../../calls/group/providers/group_call_provider.dart';
import '../../calls/providers/in_call_presence_provider.dart';
import '../../calls/providers/voice_call_provider.dart';
import '../../calls/widgets/in_call_label.dart';
import '../../profile/providers/user_status_provider.dart';
import '../../profile/widgets/user_status_badge.dart';
import '../chat-header/start_call_sheet.dart';
import '../chat-list/chat_search.dart';
import '../chat-timeline/user_profile_sheet.dart';
import '../chat_icon.dart';
import '../data/models/chat_models.dart';
import '../note_to_self_avatar.dart';
import '../providers/chat_provider.dart';
import 'details_action_button.dart';
import 'group_banner_header.dart';

/// The top of the details screen: picture, name, what this chat is, and the
/// row of square actions. Signal puts the name itself on a chevron for a 1:1
/// chat — it is a link to the person, not just a label.
class DetailsHeader extends ConsumerWidget {
  const DetailsHeader({super.key, required this.conversation});

  final ChatConversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final isDm = conversation.isDm;
    final title = conversation.displayTitle(
      ref.watch(chatProvider).currentUserId,
    );
    final avatar = isDm ? conversation.peerUserAvatar : conversation.avatarUrl;
    final callActive = ref.watch(
      voiceCallProvider.select((state) => state.active),
    );

    final banner = isDm ? null : conversation.bannerUrl;

    return Column(
      children: [
        if ((banner ?? '').isEmpty) const SizedBox(height: 8),
        // A group with a banner wears it behind the avatar, the way a profile
        // cover works everywhere else. Without one the header keeps its plain
        // spacing rather than reserving an empty band.
        if ((banner ?? '').isNotEmpty)
          GroupBannerHeader(url: banner!, title: title, avatarUrl: avatar)
        else if (conversation.isSelf)
          const NoteToSelfAvatar(size: 96, iconSize: 40)
        else
          ClipOval(
            child: AppAvatar(size: 96, url: avatar, name: title),
          ),
        const SizedBox(height: 14),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: conversation.hasDmPeer
              ? () => showUserProfileSheet(
                  context: context,
                  ref: ref,
                  userId: conversation.peerUserId!,
                  userName: conversation.peerUserName,
                  userAvatarUrl: conversation.peerUserAvatar,
                )
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (conversation.hasDmPeer)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 24,
                    color: colors.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
        _subtitle(context, ref, colors),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (conversation.hasDmPeer && conversation.canMessage)
              DetailsActionButton(
                icon: const Icon(Icons.call_rounded),
                label: 'Call',
                onTap: callActive
                    ? null
                    : () => showStartCallSheet(context, ref, conversation),
              )
            else if (conversation.isChannel)
              DetailsActionButton(
                icon: const Icon(Icons.headset_mic_rounded),
                label: 'Call',
                onTap: callActive
                    ? null
                    : () => unawaited(
                        ref
                            .read(groupCallProvider.notifier)
                            .join(conversation.id),
                      ),
              ),
            const SizedBox(width: 16),
            DetailsActionButton(
              icon: ChatIcon(
                conversation.muted
                    ? HugeIcons.strokeRoundedNotificationOff01
                    : HugeIcons.strokeRoundedNotification01,
              ),
              label: conversation.muted ? 'Unmute' : 'Mute',
              active: conversation.muted,
              onTap: () => unawaited(
                ref
                    .read(chatProvider.notifier)
                    .muteConversation(conversation.id, !conversation.muted),
              ),
            ),
            const SizedBox(width: 16),
            DetailsActionButton(
              icon: const Icon(Icons.search_rounded),
              label: 'Search',
              onTap: () => openChatSearch(
                context,
                ref,
                conversationId: conversation.id,
                conversationTitle: title,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  /// Under the name: what the group says about itself, or where the person is
  /// right now. A DM with nothing to say gets nothing rather than filler.
  Widget _subtitle(BuildContext context, WidgetRef ref, ColorScheme colors) {
    final description = conversation.description?.trim() ?? '';
    if (conversation.isGroupConversation) {
      if (description.isEmpty) return const SizedBox(height: 4);
      return Padding(
        padding: const EdgeInsets.fromLTRB(32, 6, 32, 0),
        child: Text(
          description,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant),
        ),
      );
    }
    if (conversation.isSelf) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(32, 6, 32, 0),
        child: Text(
          'Notes and files you keep here are readable only by your own '
          'devices.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant),
        ),
      );
    }
    final inCall = ref.watch(isUserInCallProvider(conversation.peerUserId));
    if (inCall) {
      return const Padding(
        padding: EdgeInsets.only(top: 6),
        child: InCallLabel(),
      );
    }
    final status = ref.watch(userStatusForProvider(conversation.peerUserId));
    if (status == null) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: UserStatusBadge(status: status),
    );
  }
}
