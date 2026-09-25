import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_toast.dart';
import '../chat-details/group_permissions.dart';
import '../chat-timeline/user_profile_sheet.dart';
import '../chat_icon.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'group_member_tags_provider.dart';
import 'member_remove.dart';
import 'member_tag_sheet.dart';

enum _MemberAction { profile, message, tag, role, permissions, remove }

/// Telegram's member actions, as a bottom sheet: the person on top, then
/// Send Message · Add Member Tag · Promote to admin · Change permissions ·
/// Remove from group. Rows appear only when the server would allow them —
/// the same rule `GroupPermissions` mirrors — so nothing here answers 403.
Future<void> showGroupMemberMenu({
  required BuildContext context,
  required WidgetRef ref,
  required ChatConversation conversation,
  required ChatMember member,
}) async {
  String t(String key) => AppTranslations.translate(context, ref, key);
  final perms = GroupPermissions(conversation);
  final isSelf = member.userId == ref.read(chatProvider).currentUserId;
  final manage = perms.canManage && !isSelf;

  final choice = await showModalBottomSheet<_MemberAction>(
    context: context,
    showDragHandle: true,
    // An admin's list is seven rows. The default sheet stops at 9/16 of the
    // screen and cut Remove off on shorter phones (and in landscape); this
    // one grows to fit and scrolls past the screen instead.
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheet) {
      final colors = Theme.of(sheet).colorScheme;
      Widget row(
        _MemberAction value,
        List<List<dynamic>> icon,
        String label, {
        bool danger = false,
      }) {
        final tint = danger ? colors.error : colors.onSurface;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          leading: ChatIcon(icon, color: tint),
          title: Text(label, style: TextStyle(fontSize: 16, color: tint)),
          onTap: () => Navigator.pop(sheet, value),
        );
      }

      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
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
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  member.tag.isNotEmpty
                      ? member.tag
                      : member.isAdmin
                      ? 'Admin'
                      : t('group_member_role'),
                ),
              ),
              const Divider(height: 1),
              row(
                _MemberAction.profile,
                HugeIcons.strokeRoundedUserCircle,
                t('group_member_view_profile'),
              ),
              if (!isSelf)
                row(
                  _MemberAction.message,
                  HugeIcons.strokeRoundedBubbleChat,
                  t('group_member_send_message'),
                ),
              if (perms.canSetTag(self: isSelf))
                row(
                  _MemberAction.tag,
                  HugeIcons.strokeRoundedTag01,
                  t(
                    member.tag.isNotEmpty
                        ? 'group_member_edit_tag'
                        : 'group_member_add_tag',
                  ),
                ),
              if (manage)
                row(
                  _MemberAction.role,
                  member.isAdmin
                      ? HugeIcons.strokeRoundedUserBlock01
                      : HugeIcons.strokeRoundedShieldUser,
                  t(
                    member.isAdmin
                        ? 'group_member_dismiss'
                        : 'group_member_promote',
                  ),
                ),
              if (manage && !member.isAdmin && conversation.type == 'group')
                row(
                  _MemberAction.permissions,
                  HugeIcons.strokeRoundedKey01,
                  t('group_member_change_perms'),
                ),
              if (manage && !member.isAdmin)
                row(
                  _MemberAction.remove,
                  HugeIcons.strokeRoundedUserRemove01,
                  t('group_member_remove'),
                  danger: true,
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
  if (choice == null || !context.mounted) return;
  void bump() =>
      ref.read(groupRosterRevisionProvider(conversation.id).notifier).state++;
  switch (choice) {
    case _MemberAction.profile:
      showUserProfileSheet(
        context: context,
        ref: ref,
        userId: member.userId,
        userName: member.name,
        userAvatarUrl: member.avatarUrl,
      );
    case _MemberAction.message:
      try {
        final dm = await ref.read(chatProvider.notifier).startDm(member.userId);
        if (context.mounted) context.push('/messages/${dm.id}');
      } catch (_) {
        if (context.mounted) {
          showAppToast(context, t('group_member_dm_failed'), isError: true);
        }
      }
    case _MemberAction.tag:
      await showMemberTagSheet(
        context,
        ref,
        conversationId: conversation.id,
        member: member,
      );
    case _MemberAction.role:
      try {
        await ref
            .read(chatProvider.notifier)
            .setGroupMemberRole(
              conversation.id,
              member.userId,
              member.isAdmin ? 'member' : 'admin',
            );
        bump();
      } catch (_) {
        if (context.mounted) {
          showAppToast(context, t('group_member_role_failed'), isError: true);
        }
      }
    case _MemberAction.permissions:
      await context.push(
        '/messages/${conversation.id}/members/${member.userId}/permissions',
        extra: member,
      );
    case _MemberAction.remove:
      await confirmRemoveMember(
        context,
        ref,
        conversationId: conversation.id,
        member: member,
      );
  }
}
