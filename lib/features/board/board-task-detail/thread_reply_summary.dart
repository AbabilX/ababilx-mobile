import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../messages/tiptap_plain_text.dart';
import '../data/models/board_models.dart';

class ThreadReplySummary extends StatelessWidget {
  const ThreadReplySummary({
    super.key,
    required this.root,
    required this.replies,
    required this.onTap,
  });

  final KanbanTaskComment root;
  final List<KanbanTaskComment> replies;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final total = replies.length + 1;
    final title = _threadTitle(root);
    final preview = _threadPreview(replies);
    final participants = _participants(root, replies);

    return Padding(
      padding: const EdgeInsets.only(left: 42, bottom: 12),
      child: Material(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.55),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '$total message${total == 1 ? '' : 's'} ›',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (participants.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _ParticipantStack(participants: participants),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ParticipantStack extends StatelessWidget {
  const _ParticipantStack({required this.participants});

  final List<_Participant> participants;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16.0 + (participants.length - 1) * 14.0 + 16.0,
      height: 24,
      child: Stack(
        children: [
          for (var i = 0; i < participants.length; i++)
            Positioned(
              left: i * 14.0,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: Theme.of(context).colorScheme.surface,
                backgroundImage: participants[i].avatarUrl != null
                    ? CachedNetworkImageProvider(participants[i].avatarUrl!)
                    : null,
                child: participants[i].avatarUrl == null
                    ? Text(
                        participants[i].initial,
                        style: const TextStyle(fontSize: 9),
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _Participant {
  const _Participant({
    required this.initial,
    this.avatarUrl,
  });

  final String initial;
  final String? avatarUrl;
}

String _threadTitle(KanbanTaskComment root) {
  final plain = tiptapToPlainText(root.body).trim();
  if (plain.isNotEmpty) return plain;
  return root.userName ?? 'Thread';
}

String _threadPreview(List<KanbanTaskComment> replies) {
  if (replies.isEmpty) {
    return 'No replies yet — tap to open thread';
  }
  final latest = replies.reduce((a, b) {
    return DateTime.parse(b.createdAt).isAfter(DateTime.parse(a.createdAt))
        ? b
        : a;
  });
  final plain = tiptapToPlainText(latest.body).trim();
  if (plain.isNotEmpty) return plain;
  return '${latest.userName ?? 'Someone'} replied';
}

List<_Participant> _participants(
  KanbanTaskComment root,
  List<KanbanTaskComment> replies,
) {
  final map = <String, _Participant>{};
  for (final m in [root, ...replies]) {
    final name = m.userName ?? 'Member';
    map[m.userId] = _Participant(
      initial: name.characters.first.toUpperCase(),
      avatarUrl: m.userAvatarUrl,
    );
  }
  return map.values.take(3).toList();
}
