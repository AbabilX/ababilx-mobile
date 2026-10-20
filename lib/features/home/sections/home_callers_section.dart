import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../../calls/calls-list/call_redial.dart';
import '../../calls/group/providers/group_call_provider.dart';
import '../../calls/providers/voice_call_provider.dart';
import '../../messages/chat_icon.dart';
import '../data/home_callers.dart';
import '../quick-views/quick_view_summary.dart';
import 'home_section.dart';

/// "Talk again": the people this account calls most, as capsules — face,
/// name, and a round call button. The capsule opens the chat; only the
/// button places the call, so a stray tap never rings anyone.
class HomeCallersSection extends ConsumerWidget {
  const HomeCallersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callers = ref.watch(homeFrequentCallersProvider);
    if (callers.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final busy =
        ref.watch(voiceCallProvider.select((s) => s.active)) ||
        ref.watch(groupCallProvider.select((s) => s.active));
    return HomeSection(
      title: homeText(context, ref, 'home_talk_again'),
      actionLabel: homeText(context, ref, 'home_see_all'),
      onAction: () => context.go('/calls'),
      child: HomeStrip(
        height: HomeCapsule.heightFor(context),
        children: [
          for (final caller in callers)
            HomeCapsule(
              key: ValueKey(caller.latest.conversationId),
              leading: (size) => AppAvatar(
                size: size,
                url: caller.latest.avatarUrl,
                name: caller.latest.title,
              ),
              label: caller.latest.title,
              onTap: () =>
                  context.push('/messages/${caller.latest.conversationId}'),
              trailing: IconButton.filled(
                onPressed: busy
                    ? null
                    : () => redialCall(
                        context,
                        ref,
                        caller.latest.conversationId,
                        isGroup: false,
                      ),
                visualDensity: VisualDensity.compact,
                icon: ChatIcon(
                  HugeIcons.strokeRoundedCall02,
                  size: 18,
                  color: colors.onPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
