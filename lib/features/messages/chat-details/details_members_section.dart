import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../chat_icon.dart';
import '../data/models/chat_models.dart';
import 'add_members_sheet.dart';
import 'details_member_tile.dart';
import 'group_permissions.dart';

/// The roster block: "N members", an Add row, then the first
/// [previewCount] people, admins first (the server already orders them that
/// way). A longer roster ends in "See all members", which opens the full
/// list on its own page.
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

  /// How many members the details screen draws before "See all".
  static const previewCount = 4;

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
        for (final member in members.take(previewCount))
          DetailsMemberTile(conversation: conversation, member: member),
        if (members.length > previewCount)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: ChatIcon(HugeIcons.strokeRoundedUserMultiple),
              ),
            ),
            title: Text(
              t('group_members_see_all'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            trailing: ChatIcon(
              HugeIcons.strokeRoundedArrowRight01,
              size: 18,
              color: colors.onSurfaceVariant,
            ),
            onTap: () => context.push(
              '/messages/${conversation.id}/members',
              extra: members,
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
