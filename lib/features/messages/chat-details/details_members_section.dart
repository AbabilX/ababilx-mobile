import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_avatar.dart';
import 'add_members_sheet.dart';
import '../data/models/chat_models.dart';
import 'avatar_preview.dart';
import '../group-member-permissions/member_actions_menu.dart';
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
    // A private group (server 0154) hands a non-admin only the admins and
    // themselves, so the count comes from the conversation, not the list.
    final hidden = conversation.groupPrivacy && !conversation.iAmAdmin;
    String t(String key) => AppTranslations.translate(context, ref, key);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Text(
            hidden
                ? t('group_privacy_members_count').replaceAll(
                    '{count}',
                    '${conversation.memberCount ?? members.length}',
                  )
                : loading && members.isEmpty
                ? 'Members'
                : '${members.length} member${members.length == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        if (hidden)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              t('group_privacy_members_hidden'),
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
          ),
        if (GroupPermissions(conversation).canAddMembers)
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
            leading: _memberAvatar(context, member),
            title: Text(
              member.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            // An admin sees who an admin restricted (server 0157).
            subtitle: member.restricted
                ? Text(t('group_perm_restricted_label'))
                : null,
            // Telegram's right side: the member's tag, else "Admin".
            trailing: _roleLabel(member, colors),
            onTap: () => showGroupMemberMenu(
              context: context,
              ref: ref,
              conversation: conversation,
              member: member,
            ),
          ),
        ),
      ],
    );
  }

  Widget? _roleLabel(ChatMember member, ColorScheme colors) {
    final label = member.tag.isNotEmpty
        ? member.tag
        : member.isAdmin
        ? 'Admin'
        : null;
    if (label == null) return null;
    return Text(
      label,
      style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant),
    );
  }

  /// The face opens the picture; the rest of the row still opens the
  /// member sheet. A letter fallback has no photo, so it stays on the row.
  Widget _memberAvatar(BuildContext context, ChatMember member) {
    final photo = ClipOval(
      child: AppAvatar(size: 44, url: member.avatarUrl, name: member.name),
    );
    if (previewPhotoUrl(member.avatarUrl) == null) return photo;
    return Semantics(
      button: true,
      label: 'View photo',
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('member-avatar-preview-${member.userId}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => openAvatarPreview(
          context,
          url: member.avatarUrl,
          name: member.name,
        ),
        child: photo,
      ),
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
