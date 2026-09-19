import 'package:flutter/material.dart';
import 'package:ababilx/shared/widgets/app_bar_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../calls/providers/in_call_presence_provider.dart';
import '../../calls/providers/voice_call_provider.dart';
import '../../calls/widgets/in_call_label.dart';
import '../../profile/providers/user_status_provider.dart';
import '../../profile/widgets/user_status_badge.dart';
import '../chat_icon.dart';
import '../data/models/chat_models.dart';
import '../nav_back.dart';
import '../providers/chat_provider.dart';
import '../providers/chat_connections_provider.dart';
import 'call_action_pill.dart';
import 'header_avatar.dart';
import 'group_call_action.dart';
import 'start_audio_call.dart';
import '../nickname/contact_nickname_provider.dart';
import '../nickname/nickname_title.dart';
import '../chat-typing/typing_text.dart';

/// Conversation top bar — used inside the scroll shell (auto-hides on scroll).
class ChatHeader extends ConsumerWidget {
  const ChatHeader({super.key, required this.conversation});
  final ChatConversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = ref
        .watch(contactNicknamesProvider)
        .titleFor(conversation, ref.watch(chatProvider).currentUserId);
    final colors = Theme.of(context).colorScheme;
    final surface =
        Theme.of(context).appBarTheme.backgroundColor ?? colors.surface;
    final callActive = ref.watch(
      voiceCallProvider.select((state) => state.active),
    );
    // hasDmPeer, not isDm: a note to self is a DM whose peer is the viewer, so
    // these would report the viewer's own presence back at them.
    final peerInCall =
        conversation.hasDmPeer &&
        ref.watch(isUserInCallProvider(conversation.peerUserId));
    final peerStatus = conversation.hasDmPeer && !peerInCall
        ? ref.watch(userStatusForProvider(conversation.peerUserId))
        : null;
    // Typing wins the subtitle while it lasts: it is the most current thing
    // anyone in the chat is doing.
    final typingText = conversation.isSelf || conversation.isWebhook
        ? ''
        : watchTypingText(
            ref,
            conversation.id,
            isGroup: conversation.isGroupConversation,
          );

    return Material(
      color: surface,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: NavigationToolbar(
            leading: AppBarBackButton(
              onPressed: () => popOrGoMessages(context),
            ),
            middle: InkWell(
              // Signal: the name is a link to the conversation's own settings
              // screen, not a sheet over the thread.
              onTap: () async {
                if (conversation.isGroupConversation) {
                  // The Add-members picker on that screen reads this list.
                  await ref.read(chatConnectionsProvider.notifier).refresh();
                  if (!context.mounted) return;
                }
                if (context.mounted) {
                  context.push('/messages/${conversation.id}/details');
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The picture the group chose belongs where the group is
                    // named, not only on the settings screen you set it from.
                    ChatHeaderAvatar(conversation: conversation, title: title),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          if (typingText.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                typingText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colors.primary,
                                ),
                              ),
                            )
                          else if (peerInCall)
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: InCallLabel(compact: true),
                            )
                          else if (peerStatus != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: UserStatusBadge(
                                status: peerStatus,
                                compact: true,
                              ),
                            )
                          else if (conversation.isGroupConversation &&
                              conversation.memberCount != null)
                            Text(
                              '${conversation.memberCount} members',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (conversation.muted)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ChatIcon(
                      HugeIcons.strokeRoundedNotificationOff01,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                // A note to self has no callee: the server finds no second
                // member and answers voice_call_peer_unavailable.
                if (conversation.hasDmPeer &&
                    conversation.canMessage &&
                    !conversation.isAccountDeleted)
                  CallActionPill(
                    icon: Icons.call_rounded,
                    label: AppTranslations.translate(context, ref, 'chat_call'),
                    onTap: callActive
                        ? null
                        : () => startAudioCall(ref, conversation),
                  ),
                // Channels and personal groups alike; the server refuses only
                // a DM (peer-to-peer) and anything you cannot post into.
                if (conversation.canGroupCall)
                  GroupCallAction(conversation: conversation),
              ],
            ),
            centerMiddle: true,
          ),
        ),
      ),
    );
  }
}
