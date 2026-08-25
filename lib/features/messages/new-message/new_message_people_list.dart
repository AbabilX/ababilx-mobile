import 'package:flutter/material.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../data/models/chat_connection.dart';

class NewMessagePeopleList extends StatelessWidget {
  const NewMessagePeopleList({
    super.key,
    required this.people,
    required this.pendingLabel,
    required this.onTap,
  });

  final List<ChatUserSummary> people;
  final String pendingLabel;
  final ValueChanged<ChatUserSummary> onTap;

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) return const SizedBox.shrink();
    return SliverList.builder(
      itemCount: people.length,
      itemBuilder: (context, index) {
        final user = people[index];
        final letter = _letter(user.name);
        final previousLetter = index == 0
            ? null
            : _letter(people[index - 1].name);
        final showLetter = letter != previousLetter;
        final pending =
            user.connection == 'pending_in' || user.connection == 'pending_out';
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
                    if (pending)
                      Text(
                        pendingLabel,
                        style: Theme.of(context).textTheme.labelMedium,
                      )
                    else if (!user.canMessage)
                      const Icon(Icons.person_add_alt_1_rounded),
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
