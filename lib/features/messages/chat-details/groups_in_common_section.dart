import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../providers/chat_details_provider.dart';
import 'add_to_group_sheet.dart';

/// The reference app's "N groups in common" block on a person's profile: the
/// groups you already share, and a way to pull them into another one.
///
/// Both lists come from the viewer's own memberships, so this never reveals a
/// group the viewer is not already in.
class GroupsInCommonSection extends ConsumerWidget {
  const GroupsInCommonSection({
    super.key,
    required this.peerUserId,
    required this.peerName,
  });

  final String peerUserId;
  final String peerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(chatGroupsInCommonProvider(peerUserId)).valueOrNull;
    if (data == null) return const SizedBox.shrink();
    if (data.inCommon.isEmpty && data.canAdd.isEmpty) {
      return const SizedBox.shrink();
    }
    final count = data.inCommon.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Text(
            count == 0
                ? 'No groups in common'
                : '$count group${count == 1 ? '' : 's'} in common',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        if (data.canAdd.isNotEmpty)
          _AddToGroupRow(
            onTap: () => showAddToGroupSheet(
              context,
              peerUserId: peerUserId,
              peerName: peerName,
              groups: data.canAdd,
            ),
          ),
        for (final group in data.inCommon)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: AppAvatar(
              size: 44,
              url: group.avatarUrl.isEmpty ? null : group.avatarUrl,
              name: group.name,
            ),
            title: Text(
              group.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              '${group.memberCount} member${group.memberCount == 1 ? '' : 's'}',
            ),
            onTap: () => context.push('/messages/${group.id}'),
          ),
      ],
    );
  }
}

class _AddToGroupRow extends StatelessWidget {
  const _AddToGroupRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add_rounded),
      ),
      title: const Text(
        'Add to a group',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      onTap: onTap,
    );
  }
}
