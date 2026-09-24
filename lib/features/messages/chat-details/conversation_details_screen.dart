import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'details_danger_actions.dart';
import 'details_floating_chrome.dart';
import 'details_header.dart';
import 'details_members_section.dart';
import 'details_settings_section.dart';
import 'details_tile.dart';
import '../group-member-permissions/group_member_tags_provider.dart';
import '../group-privacy/group_privacy_lock.dart';
import 'group_edit_sheet.dart';
import 'group_permissions.dart';
import 'groups_in_common_section.dart';
import 'shared_media_section.dart';
import 'webhook_settings_section.dart';

/// Signal's conversation settings: a full screen, reached by tapping the name
/// in the chat header. It replaced a bottom sheet for DMs and a
/// half-height dialog for groups — one surface, one layout, both scopes.
class ConversationDetailsScreen extends ConsumerStatefulWidget {
  const ConversationDetailsScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ConversationDetailsScreen> createState() =>
      _ConversationDetailsScreenState();
}

class _ConversationDetailsScreenState
    extends ConsumerState<ConversationDetailsScreen> {
  List<ChatMember> _members = const [];
  bool _loadingMembers = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMembers());
  }

  Future<void> _loadMembers() async {
    final conversation = ref
        .read(chatProvider)
        .conversationById(widget.conversationId);
    if (conversation == null || !conversation.isGroupConversation) return;
    setState(() => _loadingMembers = true);
    try {
      final members = await ref
          .read(chatProvider.notifier)
          .listChannelMembers(widget.conversationId);
      ref
          .read(groupMemberTagsProvider.notifier)
          .seedFromRoster(widget.conversationId, members);
      if (mounted) setState(() => _members = members);
    } catch (_) {
      // Roster is best-effort: the rest of the screen still works without it.
    }
    if (mounted) setState(() => _loadingMembers = false);
  }

  @override
  Widget build(BuildContext context) {
    final conversation = ref
        .watch(chatProvider)
        .conversationById(widget.conversationId);
    if (conversation == null) {
      return const Scaffold(
        body: Center(child: Text('Conversation not found')),
      );
    }
    // A member's permissions or tag changed (server 0157): redraw the roster.
    ref.listen(groupRosterRevisionProvider(widget.conversationId), (_, _) {
      _loadMembers();
    });
    final group = conversation.isGroupConversation;
    final perms = GroupPermissions(conversation);
    final hasBanner = (conversation.headerBannerUrl ?? '').trim().isNotEmpty;
    final canEdit = group && perms.canEditInfo;

    final body = Stack(
      children: [
        ListView(
          // The screen runs edge to edge, so the last red row has to clear the
          // system navigation bar on its own.
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewPaddingOf(context).bottom + 32,
          ),
          children: [
            DetailsHeader(
              conversation: conversation,
              immersiveBanner: hasBanner,
            ),
            const DetailsSectionGap(),
            DetailsSettingsSection(conversation: conversation),
            // A feed is configured before its roster: the URL is the only part
            // of it that can be lost, and the members list is the same one every
            // other group has.
            if (conversation.isWebhook) ...[
              const DetailsSectionGap(),
              WebhookSettingsSection(conversation: conversation),
            ],
            if (group) ...[
              const DetailsSectionGap(),
              DetailsMembersSection(
                conversation: conversation,
                members: _members,
                loading: _loadingMembers,
                onChanged: _loadMembers,
              ),
            ],
            const DetailsSectionGap(),
            SharedMediaSection(conversationId: conversation.id),
            // A DM only. "Groups in common" is a fact about two people, and in a
            // group the second person is a list.
            if (conversation.hasDmPeer) ...[
              const DetailsSectionGap(),
              GroupsInCommonSection(
                peerUserId: conversation.peerUserId!,
                peerName: conversation.peerUserName ?? 'this person',
              ),
            ],
            const DetailsSectionGap(),
            DetailsDangerActions(conversation: conversation),
          ],
        ),
        DetailsFloatingChrome(
          onBanner: hasBanner,
          onBack: () => Navigator.of(context).maybePop(),
          onEdit: canEdit ? () => _openGroupEdit(conversation) : null,
        ),
      ],
    );

    // Group and member pictures open without Save / Share here too.
    return GroupPrivacyLock(
      conversationId: conversation.id,
      child: hasBanner
          ? AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle.light,
              child: Scaffold(body: body),
            )
          : Scaffold(body: body),
    );
  }

  Future<void> _openGroupEdit(ChatConversation conversation) async {
    final saved = await showGroupEditSheet(context, ref, conversation);
    if (saved && mounted) setState(() {});
  }
}
