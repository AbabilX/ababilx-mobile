import 'package:flutter/material.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../data/models/chat_connection.dart';

class NewMessagePeopleList extends StatelessWidget {
  const NewMessagePeopleList({
    super.key,
    required this.people,
    required this.emptyTitle,
    required this.emptyBody,
    required this.onTap,
    this.showLetters = true,
  });

  final List<ChatUserSummary> people;
  final String emptyTitle;
  final String emptyBody;
  final ValueChanged<ChatUserSummary> onTap;

  /// A–Z headers help a long list, not a single search hit.
  final bool showLetters;

  @override
  Widget build(BuildContext context) {
    // This sits directly in a CustomScrollView's sliver list, so *both*
    // branches have to be slivers — a plain box here is a RenderObject type
    // error that takes the whole screen down. An account with no connections
    // and no workspace, which is every brand-new one, lands on this branch
    // every single time, so it is the common path and not an edge case.
    if (people.isEmpty) {
      return SliverToBoxAdapter(
        child: _EmptyPeople(title: emptyTitle, body: emptyBody),
      );
    }
    return SliverList.builder(
      itemCount: people.length,
      itemBuilder: (context, index) {
        final user = people[index];
        final letter = _letter(user.name);
        final previousLetter = index == 0
            ? null
            : _letter(people[index - 1].name);
        final showLetter = showLetters && letter != previousLetter;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showLetter)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Text(
                  letter,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            InkWell(
              onTap: () => onTap(user),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
                child: Row(
                  children: [
                    AppAvatar(size: 48, url: user.avatarUrl, name: user.name),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (user.username.isNotEmpty)
                            Text(
                              '@${user.username}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _letter(String name) {
    final value = name.trim();
    if (value.isEmpty) return '#';
    return value.characters.first.toUpperCase();
  }
}

class _EmptyPeople extends StatelessWidget {
  const _EmptyPeople({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
      child: Column(
        children: [
          Icon(
            Icons.person_search_rounded,
            size: 42,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
