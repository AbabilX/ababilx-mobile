import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../data/models/chat_models.dart';
import 'thread_people.dart';

class ThreadSummary extends StatelessWidget {
  const ThreadSummary({
    super.key,
    required this.root,
    required this.replies,
    required this.count,
    required this.onTap,
  });

  final ChatMessage root;
  final List<ChatMessage> replies;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final people = threadParticipants(root, replies);
    final ago = formatRelativeAgo(latestReplyAt(replies));
    final label = '$count ${count == 1 ? 'reply' : 'replies'}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            if (people.isNotEmpty) ...[
              _AvatarStack(people: people),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            if (ago.isNotEmpty) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  ago,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.people});
  final List<ThreadPerson> people;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 18.0 + (people.length - 1) * 14.0,
      height: 20,
      child: Stack(
        children: [
          for (var i = 0; i < people.length; i++)
            Positioned(
              left: i * 14.0,
              child: _MiniAvatar(person: people[i], border: colors.surface),
            ),
        ],
      ),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({required this.person, required this.border});
  final ThreadPerson person;
  final Color border;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final letter =
        (person.name != null && person.name!.isNotEmpty) ? person.name![0] : '?';
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1.5),
        color: colors.surfaceContainerHighest,
      ),
      clipBehavior: Clip.antiAlias,
      child: person.avatarUrl != null
          ? CachedNetworkImage(imageUrl: person.avatarUrl!, fit: BoxFit.cover)
          : Center(
              child: Text(
                letter.toUpperCase(),
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
            ),
    );
  }
}
