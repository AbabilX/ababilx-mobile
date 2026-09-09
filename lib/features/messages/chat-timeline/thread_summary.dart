import 'package:flutter/material.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../data/models/chat_models.dart';
import 'thread_people.dart';

/// Compact thread entry under a bubble. Title is the bubble itself; this
/// row only answers "how many replies, and what was last said".
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

  /// Own bubbles sit on the right, so the stem sits on the right too.
  final bool isOwn;

  static const _cardMaxWidth = 280.0;
  static const connectorKey = Key('thread-connector');

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final people = threadParticipants(root, replies);
    final preview = threadPreview(replies);
    final label = threadReplyLabel(count);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _cardMaxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _ThreadStem(isOwn: isOwn, color: colors.outlineVariant),
          Material(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
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
                    if (people.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _AvatarStack(
                        people: people,
                        borderColor: colors.surfaceContainer,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Short vertical stem from the bubble into the chip — a line, not an L.
class _ThreadStem extends StatelessWidget {
  const _ThreadStem({required this.isOwn, required this.color});

  final bool isOwn;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(left: isOwn ? 0 : 14, right: isOwn ? 14 : 0),
        child: Container(
          key: ThreadSummary.connectorKey,
          width: 2,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.people, required this.borderColor});

  final List<ThreadPerson> people;
  final Color borderColor;

  static const _size = 22.0;
  static const _overlap = 8.0;

  @override
  Widget build(BuildContext context) {
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
                border: Border.all(color: borderColor, width: 1.5),
                letterStyle: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
