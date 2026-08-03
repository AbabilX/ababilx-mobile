import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../../team/data/models/team_models.dart';
import '../providers/chat_provider.dart';
import '../providers/team_gate_provider.dart';

/// Pick a team member to share into the composer as a contact snippet.
Future<TeamMember?> showShareContactSheet(BuildContext context) {
  return showModalBottomSheet<TeamMember>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _ShareContactSheet(),
  );
}

class _ShareContactSheet extends ConsumerWidget {
  const _ShareContactSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(teamMembersProvider);
    final me = ref.watch(chatProvider).currentUserId;
    final scheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (_, scroll) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Share contact',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          Expanded(
            child: members.isEmpty
                ? Center(
                    child: Text(
                      'No contacts',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    controller: scroll,
                    itemCount: members.length,
                    itemBuilder: (_, i) {
                      final m = members[i];
                      if (m.userId == me) return const SizedBox.shrink();
                      return ListTile(
                        leading: AppAvatar(
                          size: 40,
                          url: m.avatarUrl,
                          name: m.displayName,
                        ),
                        title: Text(m.displayName),
                        subtitle: m.email != null ? Text(m.email!) : null,
                        onTap: () => Navigator.pop(context, m),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

String formatSharedContact(TeamMember member) {
  final lines = <String>['Contact: ${member.displayName}'];
  final email = member.email?.trim();
  if (email != null && email.isNotEmpty) lines.add(email);
  return lines.join('\n');
}
