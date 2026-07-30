import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../calls/providers/in_call_presence_provider.dart';
import '../../calls/providers/voice_call_provider.dart';
import '../../calls/widgets/in_call_label.dart';
import '../chat_icon.dart';
import '../data/models/chat_models.dart';
import '../nav_back.dart';
import '../providers/chat_provider.dart';
import 'dm-actions-sheet.dart';
import 'group-details-dialog.dart';

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
    final peerInCall = conversation.isDm &&
        ref.watch(isUserInCallProvider(conversation.peerUserId));

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
                if (conversation.isChannel) {
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
                    else if (conversation.isChannel &&
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
                if (conversation.isDm && !conversation.peerLeft)
                  IconButton(
                    tooltip: 'Voice call',
                    icon: const Icon(Icons.call_rounded),
                    onPressed: callActive
                        ? null
                        : () => ref
                              .read(voiceCallProvider.notifier)
                              .startOutgoing(conversation),
                  ),
                IconButton(
                  icon: const ChatIcon(HugeIcons.strokeRoundedMoreVertical),
                  onPressed: () async {
                    if (conversation.isChannel) {
                      await showGroupDetailsDialog(context, ref, conversation);
                    } else {
                      await showDmActionsSheet(context, ref, conversation);
                    }
                  },
                ),
              ],
            ),
            centerMiddle: true,
          ),
        ),
      ),
    );
  }
}
