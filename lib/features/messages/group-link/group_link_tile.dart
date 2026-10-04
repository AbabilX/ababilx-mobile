import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_toast.dart';
import '../chat-details/details_tile.dart';
import '../chat_icon.dart';
import '../data/models/chat_models.dart';
import 'group_link_payload.dart';
import 'group_link_sheet.dart';

/// "Public link" on a group's details screen (server 0167).
///
/// Admins choose the last part of the link, pause it or remove it; a tap
/// opens the sheet. Members see the row only while a link is live, and a tap
/// copies it. Independent of group privacy.
class GroupLinkTile extends ConsumerWidget {
  const GroupLinkTile({super.key, required this.conversation});

  final ChatConversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = conversation.iAmAdmin;
    final slug = conversation.publicLink;
    final paused = conversation.publicLinkPaused;
    if (!admin && (slug.isEmpty || paused)) return const SizedBox.shrink();

    return DetailsTile(
      icon: const ChatIcon(HugeIcons.strokeRoundedLink01),
      title: 'Public link',
      value: slug.isEmpty
          ? 'Off — nobody can join by link'
          : paused
          ? 'Paused · $groupLinkPrefix$slug'
          : '$groupLinkPrefix$slug',
      onTap: admin
          ? () => showGroupLinkSheet(context, conversation)
          : () async {
              await Clipboard.setData(
                ClipboardData(text: buildGroupLink(slug)),
              );
              if (context.mounted) showAppToast(context, 'Link copied');
            },
    );
  }
}
