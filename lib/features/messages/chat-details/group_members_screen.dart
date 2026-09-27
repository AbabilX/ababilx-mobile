import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/text/name_search.dart';
import '../../../shared/widgets/app_bar_back_button.dart';
import '../data/models/chat_models.dart';
import '../group-member-permissions/group_member_tags_provider.dart';
import '../group-privacy/group_privacy_lock.dart';
import '../providers/chat_provider.dart';
import 'details_member_tile.dart';
import 'members_search_field.dart';

/// Every member of a group, reached from "See all members" on the details
/// screen (which shows only the first few). Same rows, same member sheet, a
/// search on top. Opens on the roster details already had and refreshes it,
/// so it paints at once and never shows a stale list after a change.
class GroupMembersScreen extends ConsumerStatefulWidget {
  const GroupMembersScreen({
    super.key,
    required this.conversationId,
    this.initialMembers = const [],
  });

  final String conversationId;
  final List<ChatMember> initialMembers;

  @override
  ConsumerState<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends ConsumerState<GroupMembersScreen> {
  late List<ChatMember> _members = widget.initialMembers;
  late bool _loading = widget.initialMembers.isEmpty;
  bool _failed = false;
  String _query = '';

  String _t(String key) => AppTranslations.translate(context, ref, key);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final members = await ref
          .read(chatProvider.notifier)
          .listChannelMembers(widget.conversationId);
      ref
          .read(groupMemberTagsProvider.notifier)
          .seedFromRoster(widget.conversationId, members);
      if (mounted) {
        setState(() {
          _members = members;
          _failed = false;
        });
      }
    } catch (_) {
      // Keep whatever is on screen; say so only when there is nothing.
      if (mounted) setState(() => _failed = true);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    // A role, tag, removal or add anywhere redraws the list (server 0157).
    ref.listen(groupRosterRevisionProvider(widget.conversationId), (_, _) {
      _load();
    });
    final conversation = ref.watch(
      chatProvider.select((c) => c.conversationById(widget.conversationId)),
    );
    final count = _members.length;
    return GroupPrivacyLock(
      conversationId: widget.conversationId,
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBarBackButton(),
          title: Text(
            count == 0
                ? _t('group_members_title')
                : _t(
                    'group_privacy_members_count',
                  ).replaceAll('{count}', '$count'),
          ),
        ),
        body: conversation == null
            ? const SizedBox.shrink()
            : _body(conversation),
      ),
    );
  }

  Widget _body(ChatConversation conversation) {
    final colors = Theme.of(context).colorScheme;
    if (_loading && _members.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (_failed && _members.isEmpty) {
      return Center(
        child: TextButton(
          onPressed: () {
            setState(() => _loading = true);
            _load();
          },
          child: Text(_t('recovery_retry')),
        ),
      );
    }
    final shown = _query.trim().isEmpty
        ? _members
        : _members
              .where((m) => matchesNameQuery(_query, [m.name, m.tag]))
              .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: MembersSearchField(
            hint: _t('group_members_search'),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? Center(
                  child: Text(
                    _t('group_members_no_match'),
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                )
              : ListView.builder(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewPaddingOf(context).bottom + 16,
                  ),
                  itemCount: shown.length,
                  itemBuilder: (_, i) => DetailsMemberTile(
                    key: ValueKey(shown[i].userId),
                    conversation: conversation,
                    member: shown[i],
                  ),
                ),
        ),
      ],
    );
  }
}
