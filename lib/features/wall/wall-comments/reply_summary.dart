import 'package:flutter/material.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../data/models/wall_models.dart';
import '../wall_utils.dart';
import 'thread_people.dart';

/// Web-parity collapsible thread card under a root comment.
class WallReplySummary extends StatelessWidget {
  const WallReplySummary({
    super.key,
    required this.root,
    required this.replies,
    required this.onTap,
  });

  final WallComment root;
  final List<WallComment> replies;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (replies.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final total = replies.length + 1;
    final title = wallBodyPreview(root.body);
    final latest = wallLatestReply(replies);
    final preview = wallBodyPreview(latest.body);
    final people = wallThreadParticipants(root, replies);

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SummaryText(
                  title: title,
                  total: total,
                  preview: preview,
                ),
              ),
              if (people.isNotEmpty) ...[
                const SizedBox(width: 8),
                _AvatarStack(people: people),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryText extends StatelessWidget {
  const _SummaryText({
    required this.title,
    required this.total,
    required this.preview,
  });

  final String title;
  final int total;
  final String preview;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                title.isEmpty ? 'Thread' : title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$total ${total == 1 ? 'Message' : 'Messages'} ›',
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          preview.isEmpty ? 'Open thread' : preview,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.people});
  final List<WallThreadPerson> people;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 18.0 + (people.length - 1) * 12.0,
      height: 20,
      child: Stack(
        children: [
          for (var i = 0; i < people.length; i++)
            Positioned(
              left: i * 12.0,
              child: AppAvatar(
                size: 18,
                url: people[i].avatarUrl,
                name: people[i].name,
                border: Border.all(color: scheme.surface, width: 1.5),
                letterStyle: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
