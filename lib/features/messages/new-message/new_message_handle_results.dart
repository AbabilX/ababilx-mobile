import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';
import '../data/models/chat_connection.dart';
import 'new_message_people_list.dart';

/// What "Find by username" shows under the field: nothing until the handle
/// is long enough to be one (3, the server's minimum), then the person or a
/// plain "nobody has @x". Search is exact, so a half-typed handle finding no
/// one is expected — saying "no match" before it is complete would read as
/// a wrong name.
class NewMessageHandleResults extends StatelessWidget {
  const NewMessageHandleResults({
    super.key,
    required this.query,
    required this.searching,
    required this.error,
    required this.people,
    required this.noneTitle,
    required this.noneBody,
    required this.onTap,
  });

  final String query;
  final bool searching;
  final String error;
  final List<ChatUserSummary> people;
  final String noneTitle;
  final String noneBody;
  final ValueChanged<ChatUserSummary> onTap;

  @override
  Widget build(BuildContext context) {
    if (query.length < 3 || (searching && people.isEmpty)) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    if (people.isNotEmpty) {
      return NewMessagePeopleList(
        people: people,
        emptyTitle: '',
        emptyBody: '',
        onTap: onTap,
        showLetters: false,
      );
    }
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: ChatIcon(
                HugeIcons.strokeRoundedUserSearch01,
                size: 30,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              error.isEmpty ? noneTitle : error,
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (error.isEmpty) ...[
              const SizedBox(height: 6),
              Text(
                noneBody,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
