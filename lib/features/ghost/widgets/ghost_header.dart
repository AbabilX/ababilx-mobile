import 'package:flutter/material.dart';
import 'package:ababilx/shared/widgets/app_bar_back_button.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../../messages/chat_icon.dart';
import '../providers/ghost_provider.dart';
import '../providers/ghost_state.dart';
import 'ghost_labels.dart';

/// Back leaves (and so burns, after asking); the flame burns at once.
///
/// The flame asks nothing. It is the feature: whoever presses it wants the
/// chat gone from both phones now, and a confirmation would be a second in
/// which the other person is still reading.
class GhostHeader extends ConsumerWidget implements PreferredSizeWidget {
  const GhostHeader({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ghostProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final subtitle = switch (state.phase) {
      GhostPhase.inviting => ghostText(
        ref,
        'ghost_waiting',
        name: state.peerName,
      ),
      GhostPhase.live when state.peerTyping => ghostText(ref, 'ghost_typing'),
      GhostPhase.live => ghostText(ref, 'ghost_live'),
      GhostPhase.reconnecting => ghostText(ref, 'ghost_reconnecting'),
      GhostPhase.ended => '',
      _ => ghostText(ref, 'ghost_connecting'),
    };
    final canBurn = state.inSession && state.phase != GhostPhase.inviting;

    return AppBar(
      leading: IconButton(onPressed: onBack, icon: const AppBarBackIcon()),
      titleSpacing: 0,
      title: Row(
        children: [
          AppAvatar(size: 36, url: state.peerAvatarUrl, name: state.peerName),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.peerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton.filledTonal(
            tooltip: ghostText(ref, 'ghost_burn'),
            onPressed: canBurn
                ? () {
                    HapticFeedback.heavyImpact();
                    ref.read(ghostProvider.notifier).burn();
                  }
                : null,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFFF5A1F).withValues(alpha: 0.16),
            ),
            icon: const ChatIcon(
              HugeIcons.strokeRoundedFire,
              size: 24,
              strokeWidth: 1.8,
              color: Color(0xFFFF5A1F),
            ),
          ),
        ),
      ],
    );
  }
}
