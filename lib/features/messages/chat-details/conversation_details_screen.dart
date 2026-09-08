import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';
import '../data/models/chat_models.dart';
import '../nickname/contact_nickname_provider.dart';
import '../nickname/nickname_sheet.dart';
import '../providers/chat_provider.dart';
import '../safety_number/safety_number_tile.dart';
import 'details_danger_actions.dart';
import 'details_header.dart';
import 'details_members_section.dart';
import 'details_tile.dart';
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
    final group = conversation.isGroupConversation;
    final perms = GroupPermissions.of(ref, conversation);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (group && perms.canEditInfo)
            IconButton(
              tooltip: 'Edit group',
              icon: const ChatIcon(HugeIcons.strokeRoundedEdit02),
              onPressed: () async {
                final saved = await showGroupEditSheet(
                  context,
                  ref,
                  conversation,
                );
                if (saved && mounted) setState(() {});
              },
            ),
        ],
      ),
      body: ListView(
        // The screen runs edge to edge, so the last red row has to clear the
        // system navigation bar on its own.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewPaddingOf(context).bottom + 32,
        ),
        children: [
          DetailsHeader(conversation: conversation),
          const DetailsSectionGap(),
          ..._settingsTiles(conversation),
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
    );
  }

  List<Widget> _settingsTiles(ChatConversation conversation) => [
    // DM only: a nickname renames a person, and a group is not one. It sits
    // first because it is the fix for a name you cannot read.
    if (conversation.hasDmPeer)
      DetailsTile(
        icon: const ChatIcon(HugeIcons.strokeRoundedUserEdit01),
        title: 'Nickname',
        value:
            ref
                .watch(contactNicknamesProvider)
                .forUser(conversation.peerUserId) ??
            'None',
        onTap: () => showNicknameSheet(
          context,
          ref,
          userId: conversation.peerUserId!,
          profileName: conversation.peerUserName,
        ),
      ),
    // DM only: a safety number is a comparison between two identities, and a
    // group has no single peer identity to compare against.
    if (conversation.hasDmPeer)
      SafetyNumberTile(
        peerUserId: conversation.peerUserId!,
        peerName: conversation.displayTitle(
          ref.read(chatProvider).currentUserId,
        ),
      ),
    DetailsTile(
      icon: const ChatIcon(HugeIcons.strokeRoundedPaintBoard),
      title: 'Chat color & wallpaper',
      onTap: () => context.push('/messages/${conversation.id}/wallpaper'),
    ),
    DetailsTile(
      icon: ChatIcon(
        conversation.muted
            ? HugeIcons.strokeRoundedNotificationOff01
            : HugeIcons.strokeRoundedNotification01,
      ),
      title: 'Sounds & notifications',
      value: conversation.muted ? 'Muted' : 'All messages',
      trailing: Switch(
        value: !conversation.muted,
        onChanged: (on) => ref
            .read(chatProvider.notifier)
            .muteConversation(conversation.id, !on),
      ),
    ),
  ];
}
