import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calls/providers/voice_call_provider.dart';
import '../data/models/chat_models.dart';

/// Bottom sheet: Voice call (starts flow) · Video call (disabled for now).
Future<void> showStartCallSheet(
  BuildContext context,
  WidgetRef ref,
  ChatConversation conversation,
) async {
  if (!conversation.isDm || conversation.peerLeft) return;

  final colors = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Start a call',
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _CallOptionTile(
                icon: Icons.call_rounded,
                title: 'Voice call',
                subtitle: 'Audio only',
                enabled: true,
                onTap: () {
                  Navigator.of(ctx).pop();
                  ref
                      .read(voiceCallProvider.notifier)
                      .startOutgoing(conversation);
                },
              ),
              const SizedBox(height: 8),
              _CallOptionTile(
                icon: Icons.videocam_rounded,
                title: 'Video call',
                subtitle: 'Coming soon',
                enabled: false,
                onTap: null,
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _CallOptionTile extends StatelessWidget {
  const _CallOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final fg = enabled ? colors.onSurface : colors.onSurfaceVariant;
    final iconBg = enabled
        ? colors.primaryContainer
        : colors.surfaceContainerHighest;

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: enabled ? colors.onPrimaryContainer : fg,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (!enabled)
                Text(
                  'Soon',
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
