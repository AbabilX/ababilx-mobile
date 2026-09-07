import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_avatar.dart';
import 'add_members_sheet.dart';
import '../data/models/chat_models.dart';
import 'details_member_sheet.dart';
import 'group_permissions.dart';

/// The roster block: "N members", an Add row, then everyone, admins first
/// (the server already orders them that way).
class DetailsMembersSection extends ConsumerWidget {
  const DetailsMembersSection({
    super.key,
    required this.conversation,
    required this.members,
    required this.loading,
    required this.onChanged,
  });

  final ChatConversation conversation;
  final List<ChatMember> members;
  final bool loading;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Text(
            loading && members.isEmpty
                ? 'Members'
                : '${members.length} member${members.length == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        if (GroupPermissions.of(ref, conversation).canAddMembers)
          ListTile(
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
              'Add members',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            onTap: () => _openAddMembers(context, ref),
          ),
        if (loading && members.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          ),
        ...members.map(
          (member) => ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: ClipOval(
              child: AppAvatar(
                size: 44,
                url: member.avatarUrl,
                name: member.name,
              ),
            ),
            title: Text(
              member.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            trailing: member.isAdmin
                ? Text(
                    'Admin',
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.onSurfaceVariant,
                    ),
                  )
                : null,
            onTap: () => showGroupMemberSheet(
              context: context,
              ref: ref,
              conversation: conversation,
              member: member,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  void _openAddMembers(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AddMembersSheet(
        conversation: conversation,
        memberIds: members.map((m) => m.userId).toSet(),
        onAdded: onChanged,
      ),
    );
  }
}
