import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'dm_actions_sheet.dart';
import 'group_details_dialog.dart';
import 'group_call_action.dart';
import 'start_call_sheet.dart';

/// Conversation top bar — used inside the scroll shell (auto-hides on scroll).
class ChatHeader extends ConsumerWidget {
  const ChatHeader({super.key, required this.conversation});
  final ChatConversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = conversation.displayTitle(
      ref.watch(chatProvider).currentUserId,
    );
    final colors = Theme.of(context).colorScheme;
    final surface =
        Theme.of(context).appBarTheme.backgroundColor ?? colors.surface;
    final callActive = ref.watch(
      voiceCallProvider.select((state) => state.active),
    );
    final peerInCall =
        conversation.isDm &&
        ref.watch(isUserInCallProvider(conversation.peerUserId));
    final peerStatus = conversation.isDm && !peerInCall
        ? ref.watch(userStatusForProvider(conversation.peerUserId))
        : null;

    return Material(
      color: surface,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: NavigationToolbar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => popOrGoMessages(context),
            ),
            middle: InkWell(
              onTap: () async {
                if (conversation.isGroupConversation) {
                  if (conversation.isPersonal) {
                    await ref.read(chatConnectionsProvider.notifier).refresh();
                    if (!context.mounted) return;
                  }
                  await showGroupDetailsDialog(context, ref, conversation);
                } else {
                  await showDmActionsSheet(context, ref, conversation);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (peerInCall)
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
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
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
                if (conversation.isDm && conversation.canMessage)
                  CallActionPill(
                    icon: Icons.call_rounded,
                    label: AppTranslations.translate(context, ref, 'chat_call'),
                    onTap: callActive
                        ? null
                        : () => showStartCallSheet(context, ref, conversation),
                  ),
                // Group calls are channel-only, same as the server gate.
                if (conversation.isChannel)
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
