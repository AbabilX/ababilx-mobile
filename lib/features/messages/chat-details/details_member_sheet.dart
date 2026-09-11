import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat-timeline/user_profile_sheet.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'group_permissions.dart';

/// Tapping a member of a personal group you administer. Signal offers the
/// person first and the two admin actions under it, so a plain look-up never
/// starts with a destructive row.
///
/// An admin cannot be removed until demoted — that is the server's rule, and
/// the sheet mirrors it instead of offering a call that would 403.
Future<void> showGroupMemberSheet({
  required BuildContext context,
  required WidgetRef ref,
  required ChatConversation conversation,
  required ChatMember member,
  required VoidCallback onChanged,
}) async {
  final canManage = GroupPermissions(conversation).canManage;
  final isSelf = member.userId == ref.read(chatProvider).currentUserId;

  await showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          ListTile(
            title: Text(
              member.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(member.isAdmin ? 'Admin' : 'Member'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.person_outline_rounded),
            title: const Text('View profile'),
            onTap: () {
              Navigator.pop(sheet);
              showUserProfileSheet(
                context: context,
                ref: ref,
                userId: member.userId,
                userName: member.name,
                userAvatarUrl: member.avatarUrl,
              );
            },
          ),
          if (canManage && !isSelf) ...[
            ListTile(
              leading: Icon(
                member.isAdmin
                    ? Icons.remove_moderator_outlined
                    : Icons.add_moderator_outlined,
              ),
              title: Text(member.isAdmin ? 'Remove as admin' : 'Make admin'),
              onTap: () async {
                Navigator.pop(sheet);
                await _run(
                  context,
                  ref
                      .read(chatProvider.notifier)
                      .setGroupMemberRole(
                        conversation.id,
                        member.userId,
                        member.isAdmin ? 'member' : 'admin',
                      ),
                  onChanged,
                );
              },
            ),
            if (!member.isAdmin)
              ListTile(
                leading: Icon(
                  Icons.person_remove_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Remove from group',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () async {
                  Navigator.pop(sheet);
                  await _run(
                    context,
                    ref
                        .read(chatProvider.notifier)
                        .removeGroupMember(conversation.id, member.userId),
                    onChanged,
                  );
                },
              ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Future<void> _run(
  BuildContext context,
  Future<void> action,
  VoidCallback onChanged,
) async {
  try {
    await action;
    onChanged();
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Failed: $e')));
  }
}
