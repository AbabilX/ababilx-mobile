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

/// "Talk again": people this account calls most — circular face, name under
/// it, phone badge as a hint. Tapping the person places the call at once
/// (See all still opens Talks).
class HomeCallersSection extends ConsumerWidget {
  const HomeCallersSection({super.key});

  static const _face = 64.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callers = ref.watch(homeFrequentCallersProvider);
    if (callers.isEmpty) return const SizedBox.shrink();
    final busy =
        ref.watch(voiceCallProvider.select((s) => s.active)) ||
        ref.watch(groupCallProvider.select((s) => s.active));
    return HomeSection(
      title: homeText(context, ref, 'home_talk_again'),
      actionLabel: homeText(context, ref, 'home_see_all'),
      onAction: () => context.go('/calls'),
      child: HomeStrip(
        height: HomeFaceTile.heightFor(context, face: _face),
        gap: 12,
        children: [
          for (final caller in callers)
            HomeFaceTile(
              key: ValueKey(caller.latest.conversationId),
              face: _face,
              width: 76,
              label: caller.latest.title,
              avatar: _CallFace(
                url: caller.latest.avatarUrl,
                name: caller.latest.title,
                size: _face,
                enabled: !busy,
              ),
              onTap: busy
                  ? () {}
                  : () => redialCall(
                      context,
                      ref,
                      caller.latest.conversationId,
                      isGroup: false,
                    ),
            ),
        ],
      ),
    );
  }
}

/// Circular picture with a teal phone badge — decoration only; the tile
/// around it owns the tap → call.
class _CallFace extends StatelessWidget {
  const _CallFace({
    required this.url,
    required this.name,
    required this.size,
    required this.enabled,
  });

  final String? url;
  final String name;
  final double size;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final badge = enabled ? colors.primary : colors.onSurfaceVariant;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: Opacity(
              opacity: enabled ? 1 : 0.5,
              child: AppAvatar(size: size, url: url, name: name),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: badge,
                shape: BoxShape.circle,
                border: Border.all(color: colors.surface, width: 2),
              ),
              child: ChatIcon(
                HugeIcons.strokeRoundedCall02,
                size: 14,
                color: colors.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
