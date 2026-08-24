import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../providers/messageable_people_provider.dart';

Future<ChatConversation?> showNewDmDialog(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<ChatConversation>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => const NewDmSheet(),
  );
}

class NewDmSheet extends ConsumerWidget {
  const NewDmSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(messageablePeopleProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, scroll) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'New message',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              itemCount: members.length,
              itemBuilder: (_, i) {
                final m = members[i];
                return _MemberTile(
                  member: m,
                  onTap: () async {
                    final dm = await ref
                        .read(chatProvider.notifier)
                        .startDm(m.userId);
                    if (context.mounted) Navigator.pop(context, dm);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.onTap});
  final ChatUserSummary member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: AppAvatar(size: 40, url: member.avatarUrl, name: member.name),
      title: Text(member.name),
      subtitle: member.username.isEmpty ? null : Text('@${member.username}'),
      onTap: onTap,
    );
  }
}
