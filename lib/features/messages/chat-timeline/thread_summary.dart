import 'package:flutter/material.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../data/models/chat_models.dart';
import 'thread_people.dart';

/// Quote-rail under a bubble: a 3px bar, reply count, last message in muted
/// gray, faces. No card, no stem.
class ThreadSummary extends StatelessWidget {
  const ThreadSummary({
    super.key,
    required this.root,
    required this.replies,
    required this.count,
    required this.onTap,
    this.isOwn = false,
  });

  final ChatMessage root;
  final List<ChatMessage> replies;
  final int count;
  final VoidCallback onTap;
  final bool isOwn;

  static const railKey = Key('thread-rail');
  static const _cardMaxWidth = 280.0;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final people = threadParticipants(root, replies);
    final preview = threadPreview(replies);
    final label = threadReplyLabel(count);
    final rail = _QuoteRail(color: colors.primary);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _cardMaxWidth),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isOwn) ...[rail, const SizedBox(width: 8)],
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      crossAxisAlignment: isOwn
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              label,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: colors.primary,
                            ),
                          ],
                        ),
                        if (preview.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (people.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Align(
                    alignment: Alignment.center,
                    child: _AvatarStack(people: people),
                  ),
                ],
                if (isOwn) ...[const SizedBox(width: 8), rail],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuoteRail extends StatelessWidget {
  const _QuoteRail({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ThreadSummary.railKey,
      width: 3,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.people});

  final List<ThreadPerson> people;

  static const _size = 20.0;
  static const _overlap = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: _size + (people.length - 1) * (_size - _overlap),
      height: _size,
      child: Stack(
        children: [
          for (var i = 0; i < people.length; i++)
            Positioned(
              left: i * (_size - _overlap),
              child: AppAvatar(
                size: _size,
                url: people[i].avatarUrl,
                name: people[i].name,
                border: Border.all(color: colors.surface, width: 1.5),
                letterStyle: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
