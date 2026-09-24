import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:go_router/go_router.dart';

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
import 'exception_member_picker.dart';
import 'permission_section.dart';
import 'permission_list.dart';

/// Group → Permissions: what every member may do, and the members an admin
/// restricted further (Telegram's Exceptions). Admins only.
class GroupPermissionsScreen extends ConsumerStatefulWidget {
  const GroupPermissionsScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<GroupPermissionsScreen> createState() =>
      _GroupPermissionsScreenState();
}

class _GroupPermissionsScreenState
    extends ConsumerState<GroupPermissionsScreen> {
  GroupMemberPerms? _defaults;
  GroupMemberPerms? _initial;
  List<ChatMember> _members = const [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final conversation = ref
        .read(chatProvider)
        .conversationById(widget.conversationId);
    _initial = conversation?.defaultPermissions ?? GroupMemberPerms.all;
    _defaults = _initial;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMembers());
  }

  String _t(String key) => AppTranslations.translate(context, ref, key);

  Future<void> _loadMembers() async {
    try {
      final members = await ref
          .read(chatProvider.notifier)
          .listChannelMembers(widget.conversationId);
      ref
          .read(groupMemberTagsProvider.notifier)
          .seedFromRoster(widget.conversationId, members);
      if (mounted) setState(() => _members = members);
    } catch (_) {
      // The defaults still work without the roster.
    }
  }

  Future<void> _save() async {
    final next = _defaults;
    if (_saving || next == null || next == _initial) return;
    setState(() => _saving = true);
    try {
      final updated = await putGroupDefaultPermissions(
        ref.read(apiClientProvider),
        widget.conversationId,
        next,
      );
      ref.read(chatProvider.notifier).upsertChannel(updated);
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

  Future<void> _openMember(ChatMember member) async {
    await context.push(
      '/messages/${widget.conversationId}/members/${member.userId}/permissions',
      extra: member,
    );
    if (mounted) await _loadMembers();
  }

  Future<void> _addException() async {
    final picked = await pickExceptionMember(
      context,
      _members.where((m) => !m.isAdmin && !m.restricted).toList(),
    );
    if (picked != null && mounted) await _openMember(picked);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(groupRosterRevisionProvider(widget.conversationId), (_, _) {
      _loadMembers();
    });
    final defaults = _defaults ?? GroupMemberPerms.all;
    final restricted = _members.where((m) => m.restricted).toList();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: Text(_t('group_perm_title_group')),
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
                  onPressed: defaults != _initial ? _save : null,
                  child: Text(_t('group_tag_save')),
                ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.only(
          top: 8,
          bottom: MediaQuery.viewPaddingOf(context).bottom + 24,
        ),
        children: [
          PermissionSection(
            divider: false,
            heading: _t('group_perm_what_members'),
            footer: _t('group_perm_admin_note'),
            children: [
              PermissionList(
                value: defaults,
                onChanged: (next) => setState(() => _defaults = next),
              ),
            ],
          ),
          PermissionSection(
            heading: _t('group_perm_exceptions'),
            footer: restricted.isEmpty ? _t('group_perm_no_exceptions') : null,
            children: [
              DetailsTile(
                icon: const ChatIcon(HugeIcons.strokeRoundedUserAdd01),
                title: _t('group_perm_add_exception'),
                onTap: _members.isEmpty ? null : _addException,
              ),
              for (final m in restricted)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: ClipOval(
                    child: AppAvatar(size: 40, url: m.avatarUrl, name: m.name),
                  ),
                  title: Text(m.name),
                  subtitle: Text(
                    _t('group_perm_restricted_label'),
                    style: TextStyle(color: muted),
                  ),
                  trailing: ChatIcon(
                    HugeIcons.strokeRoundedArrowRight01,
                    size: 18,
                    color: muted,
                  ),
                  onTap: () => _openMember(m),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
