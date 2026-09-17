import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../../messages/chat_icon.dart';
import '../providers/ghost_provider.dart';
import '../providers/ghost_state.dart';
import '../widgets/ghost_labels.dart';

/// The invitee's full screen: who is asking, Join or Decline.
///
/// It navigates nowhere itself — `GhostSync` owns every Ghost Chat route, so
/// Join and Decline only change the provider and the route follows.
class GhostInviteScreen extends ConsumerStatefulWidget {
  const GhostInviteScreen({super.key});

  @override
  ConsumerState<GhostInviteScreen> createState() => _GhostInviteScreenState();
}

class _GhostInviteScreenState extends ConsumerState<GhostInviteScreen> {
  Timer? _pulse;

  @override
  void initState() {
    super.initState();
    // A soft, repeating nudge — this is an invite, not a phone call.
    HapticFeedback.mediumImpact();
    _pulse = Timer.periodic(
      const Duration(seconds: 2),
      (_) => HapticFeedback.lightImpact(),
    );
  }

  @override
  void dispose() {
    _pulse?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ghostProvider);
    final notifier = ref.read(ghostProvider.notifier);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final busy = state.phase == GhostPhase.accepting;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) notifier.decline();
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              children: [
                const Spacer(),
                AppAvatar(
                  size: 112,
                  url: state.peerAvatarUrl,
                  name: state.peerName,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ChatIcon(
                      HugeIcons.strokeRoundedIncognito,
                      size: 22,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      ghostText(ref, 'ghost_chip'),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  ghostText(ref, 'ghost_invite_title', name: state.peerName),
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  ghostText(ref, 'ghost_invite_body'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(flex: 2),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: busy ? null : notifier.decline,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.error,
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: Text(ghostText(ref, 'ghost_decline')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: busy ? null : notifier.accept,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: busy
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(ghostText(ref, 'ghost_join')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
