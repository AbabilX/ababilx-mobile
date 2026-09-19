import 'package:flutter/material.dart';
import 'package:ababilx/shared/widgets/app_bar_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../calls/providers/voice_call_provider.dart';
import '../chat-header/call_action_pill.dart';
import '../chat-header/start_audio_call.dart';
import '../data/models/chat_models.dart';

/// Thread screen top bar — Slack-style: "Thread" title, a subtitle telling
/// you which conversation it belongs to, the conversation's avatar, and
/// (DMs only) a call button — mirrors ChatHeader's trailing call affordance.
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

    return Material(
      color: Theme.of(context).appBarTheme.backgroundColor ?? colors.surface,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: NavigationToolbar(
            leading: AppBarBackButton(onPressed: () => Navigator.of(context).pop()),
            middle: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Thread',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                if (subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: colors.primary),
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppAvatar(size: 30, url: avatarUrl, name: avatarName),
                if (convo != null &&
                    convo.isDm &&
                    convo.canMessage &&
                    !convo.isAccountDeleted)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: CallActionPill(
                      icon: Icons.call_rounded,
                      label: AppTranslations.translate(
                        context,
                        ref,
                        'chat_call',
                      ),
                      onTap: callActive
                          ? null
                          : () => startAudioCall(ref, convo),
                    ),
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
