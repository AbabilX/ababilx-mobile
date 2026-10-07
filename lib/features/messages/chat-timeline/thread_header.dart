import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../calls/providers/voice_call_provider.dart';
import '../chat-header/start_audio_call.dart';
import '../chat-pins/pinned_messages_chrome.dart';
import '../data/models/chat_models.dart';

/// Thread screen top bar, cut from the pinned-messages header: a round back
/// button, a capsule naming the thread and the conversation it belongs to
/// (with that conversation's picture inside), and — in a DM — a round call
/// button. The call button keeps the capsule centred; without it a spacer does.
class ThreadHeader extends ConsumerWidget {
  const ThreadHeader({super.key, required this.conversation});
  final ChatConversation? conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final convo = conversation;
    final subtitle = convo == null
        ? ''
        : convo.isDm
        ? 'Direct message'
        : (convo.name != null ? '#${convo.name}' : 'Channel');
    final avatarUrl = convo?.isAccountDeleted == true
        ? null
        : convo?.isDm == true
        ? convo?.peerUserAvatar
        : convo?.avatarUrl;
    final avatarName = convo?.isDm == true
        ? (convo?.peerUserName ?? '?')
        : (convo?.name ?? '?');
    final callActive = ref.watch(
      voiceCallProvider.select((state) => state.active),
    );
    final canCall =
        convo != null &&
        convo.isDm &&
        convo.canMessage &&
        !convo.isAccountDeleted;
    final label = AppTranslations.translate(context, ref, 'chat_call');
    final back = AppTranslations.translate(context, ref, 'recovery_back');

    return PinnedMessagesTopBar(
      title: 'Thread',
      bottomPadding: 8,
      reserveTrailing: false,
      backLabel: canCall ? null : back,
      middle: HeaderPill(
        shape: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 18, 6),
          child: Row(
            children: [
              AppAvatar(size: 32, url: avatarUrl, name: avatarName),
              const SizedBox(width: 10),
              Expanded(child: _names(context, colors, subtitle)),
            ],
          ),
        ),
      ),
      trailing: !canCall
          ? null
          : PinnedMessagesCircleButton(
              icon: HugeIcons.strokeRoundedCall,
              tooltip: label,
              onPressed: callActive ? null : () => startAudioCall(ref, convo),
            ),
    );
  }

  Widget _names(BuildContext context, ColorScheme colors, String subtitle) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thread',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.2,
                color: colors.primary,
              ),
            ),
        ],
      );
}
