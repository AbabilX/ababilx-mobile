import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat-details/details_tile.dart';
import '../chat_icon.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_bar_back_button.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'group_admin_api.dart';
import 'group_member_tags_provider.dart';
import 'member_remove.dart';
import 'member_tag_editor.dart';
import 'permission_section.dart';
import 'permission_list.dart';

/// Telegram's "User Permissions": what one member may do, their tag, and the
/// way out of the group. Admins only — the menu offers it to nobody else and
/// the server refuses anyone else. Saved with the check in the app bar.
class UserPermissionsScreen extends ConsumerStatefulWidget {
  const UserPermissionsScreen({
    super.key,
    required this.conversationId,
    required this.member,
  });

  final String conversationId;
  final ChatMember member;

  @override
  ConsumerState<UserPermissionsScreen> createState() =>
      _UserPermissionsScreenState();
}

class _UserPermissionsScreenState extends ConsumerState<UserPermissionsScreen> {
  late GroupMemberPerms _perms;
  late final GroupMemberPerms _initial;
  late final TextEditingController _tag;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _initial = widget.member.permissions ?? GroupMemberPerms.all;
    _perms = _initial;
    _tag = TextEditingController(text: widget.member.tag)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tag.dispose();
    super.dispose();
  }

  String _t(String key) => AppTranslations.translate(context, ref, key);

  GroupMemberPerms get _defaults =>
      ref
          .read(chatProvider)
          .conversationById(widget.conversationId)
          ?.defaultPermissions ??
      GroupMemberPerms.all;

  bool get _dirty =>
      _perms != _initial || _tag.text.trim() != widget.member.tag;

  Future<void> _save() async {
    if (_saving || !_dirty) return;
    setState(() => _saving = true);
    final client = ref.read(apiClientProvider);
    try {
      if (_perms != _initial) {
        await putMemberPermissions(
          client,
          widget.conversationId,
          widget.member.userId,
          memberExceptionOnly(_perms, _defaults),
        );
      }
      final tag = _tag.text.trim();
      if (tag != widget.member.tag) {
        final stored = await putMemberTag(
          client,
          widget.conversationId,
          widget.member.userId,
          tag,
        );
        ref
            .read(groupMemberTagsProvider.notifier)
            .setTag(widget.conversationId, widget.member.userId, stored);
      }
      ref
          .read(groupRosterRevisionProvider(widget.conversationId).notifier)
          .state++;
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppToast(
        context,
        groupPermissionErrorText(context, ref, error),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: Text(_t('group_perm_title_user')),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : TextButton(
                  onPressed: _dirty ? _save : null,
                  child: Text(_t('group_tag_save')),
                ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewPaddingOf(context).bottom + 24,
        ),
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            leading: ClipOval(
              child: AppAvatar(
                size: 48,
                url: member.avatarUrl,
                name: member.name,
              ),
            ),
            title: Text(
              member.name,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              member.tag.isNotEmpty ? member.tag : _t('group_member_role'),
              style: TextStyle(color: muted),
            ),
          ),
          PermissionSection(
            heading: _t('group_perm_what_user'),
            children: [
              PermissionList(
                value: _perms,
                groupDefaults: _defaults,
                onChanged: (next) => setState(() => _perms = next),
              ),
            ],
          ),
          PermissionSection(
            heading: _t('group_tag_title'),
            footer: _t('group_tag_help').replaceAll('{name}', member.name),
            children: [MemberTagEditor(member: member, controller: _tag)],
          ),
          PermissionSection(
            children: [
              DetailsTile(
                icon: const ChatIcon(HugeIcons.strokeRoundedUserRemove01),
                title: _t('group_member_remove'),
                destructive: true,
                onTap: () async {
                  final removed = await confirmRemoveMember(
                    context,
                    ref,
                    conversationId: widget.conversationId,
                    member: member,
                  );
                  if (removed && context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
