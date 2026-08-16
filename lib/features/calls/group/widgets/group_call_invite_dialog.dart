import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_avatar.dart';
import '../data/models/group_call.dart';
import '../providers/group_call_provider.dart';

/// Ringing card for a channel group call, mirroring the incoming 1:1 call
/// screen: one Join button and one Deny button, nothing else to get wrong.
///
/// Deny is local only — the call keeps running for everyone else and the
/// channel header still offers "Join".
class GroupCallInviteDialog extends ConsumerWidget {
  const GroupCallInviteDialog({super.key, required this.call});

  final GroupCall call;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(groupCallProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppAvatar(
                        size: 96,
                        url: call.starterAvatarUrl,
                        name: call.title,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        call.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${call.starterName} started a group call',
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      if (call.participantCount > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.group_rounded,
                              size: 14,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${call.participantCount} already in call',
                              style: text.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _AnswerButton(
                            icon: Icons.headset_mic_rounded,
                            label: 'Join',
                            background: const Color(0xFF22C55E),
                            onTap: notifier.acceptInvite,
                          ),
                          const SizedBox(width: 36),
                          _AnswerButton(
                            icon: Icons.call_end_rounded,
                            label: 'Deny',
                            background: colors.error,
                            onTap: notifier.declineInvite,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 68,
            height: 68,
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(label, style: Theme.of(context).textTheme.labelLarge),
    ],
  );
}
