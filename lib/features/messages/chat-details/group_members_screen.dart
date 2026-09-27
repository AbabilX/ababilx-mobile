import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/text/name_search.dart';
import '../chat-pins/header_search_field.dart';
import '../chat-pins/pinned_messages_chrome.dart';
import '../data/models/chat_models.dart';
import '../group-member-permissions/group_member_tags_provider.dart';
import '../group-privacy/group_privacy_lock.dart';
import '../providers/chat_provider.dart';
import 'details_member_tile.dart';

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
  bool _searching = false;

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

  void _closeSearch() => setState(() {
    _searching = false;
    _query = '';
  });

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
    // The Pins page's floating header: round back button + title capsule,
    // the list scrolling underneath the fade.
    final page = GroupPrivacyLock(
      conversationId: widget.conversationId,
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: conversation == null
                  ? const SizedBox.shrink()
                  : _body(conversation),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: PinnedMessagesTopBar(
                title: count == 0
                    ? _t('group_members_title')
                    : _t(
                        'group_privacy_members_count',
                      ).replaceAll('{count}', '$count'),
                // Searching swaps the title capsule for the field and the
                // search button for a close button.
                middle: _searching
                    ? HeaderSearchField(
                        hint: _t('group_members_search'),
                        autofocus: true,
                        onChanged: (value) => setState(() => _query = value),
                      )
                    : null,
                trailing: PinnedMessagesCircleButton(
                  icon: _searching
                      ? HugeIcons.strokeRoundedCancel01
                      : HugeIcons.strokeRoundedSearch01,
                  tooltip: _t('group_members_search'),
                  onPressed: _searching
                      ? _closeSearch
                      : () => setState(() => _searching = true),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    // Back closes the search before it leaves the page.
    return PopScope(
      canPop: !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeSearch();
      },
      child: page,
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
    final insets = MediaQuery.viewPaddingOf(context);
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(
        top: insets.top + 68,
        bottom: insets.bottom + 16,
      ),
      itemCount: shown.isEmpty ? 1 : shown.length,
      itemBuilder: (_, i) {
        if (shown.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Text(
              _t('group_members_no_match'),
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          );
        }
        final member = shown[i];
        return DetailsMemberTile(
          key: ValueKey(member.userId),
          conversation: conversation,
          member: member,
        );
      },
    );
  }
}
