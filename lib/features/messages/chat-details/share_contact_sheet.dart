import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../chat_icon.dart';
import '../data/models/chat_conversation.dart';
import 'share_contact.dart';

/// Share on a DM's details: a bottom sheet with the person's deep link and
/// three ways to pass it on — copy it, hand it to another app, or send it in a
/// chat here.
///
/// Only reachable while [ChatConversation.canShareContact], which the server
/// grants only while the person lets strangers find them (a discovery switch
/// on, privacy mode off). Someone who hid themselves is never passed around
/// from here, and a link already shared stops opening once they hide.
Future<void> showShareContactSheet(
  BuildContext context,
  WidgetRef ref,
  ChatConversation conversation,
) async {
  final link = sharedContactLink(conversation);
  if (link.isEmpty) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => _ShareContactSheet(
      conversation: conversation,
      link: link,
      // The details screen's context, not the sheet's: the sheet is gone by
      // the time a chat picker or a toast needs one.
      host: context,
    ),
  );
}

class _ShareContactSheet extends ConsumerWidget {
  const _ShareContactSheet({
    required this.conversation,
    required this.link,
    required this.host,
  });

  final ChatConversation conversation;
  final String link;
  final BuildContext host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    String tr(String key) => AppTranslations.translate(context, ref, key);
    final name = conversation.peerUserName?.trim() ?? '';
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              tr('chat_share_contact'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              link,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
          ),
          ListTile(
            leading: const ChatIcon(HugeIcons.strokeRoundedCopy01),
            title: Text(tr('chat_copy_link')),
            onTap: () async {
              final copied = tr('chat_link_copied');
              await Clipboard.setData(ClipboardData(text: link));
              if (!context.mounted) return;
              Navigator.of(context).pop();
              if (host.mounted) showAppToast(host, copied);
            },
          ),
          ListTile(
            leading: const ChatIcon(HugeIcons.strokeRoundedShare08),
            title: Text(tr('chat_share_via')),
            onTap: () {
              final text = name.isEmpty
                  ? link
                  : '${tr('chat_share_contact_text').replaceAll('{name}', name)}: $link';
              Navigator.of(context).pop();
              SharePlus.instance.share(ShareParams(text: text));
            },
          ),
          ListTile(
            leading: const ChatIcon(HugeIcons.strokeRoundedSent),
            title: Text(tr('chat_send_in_chat')),
            onTap: () {
              Navigator.of(context).pop();
              if (host.mounted) sendContactToChats(host, ref, conversation);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
