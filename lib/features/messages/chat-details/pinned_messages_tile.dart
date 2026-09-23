import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../chat_icon.dart';
import '../providers/pinned_message_provider.dart';
import 'details_tile.dart';

/// "Pinned messages" on the details screen. Choosing one closes this screen
/// with its id, and the chat under it walks to that message.
class PinnedMessagesTile extends ConsumerWidget {
  const PinnedMessagesTile({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String tr(String key) => AppTranslations.translate(context, ref, key);
    final count = ref
        .watch(pinnedMessagesProvider(conversationId))
        .valueOrNull
        ?.length;
    return DetailsTile(
      icon: const ChatIcon(HugeIcons.strokeRoundedPin),
      title: tr('chat_pinned_messages'),
      value: count == null
          ? null
          : count == 0
          ? tr('chat_pins_none')
          : '$count',
      onTap: () async {
        final messageId = await context.push<String>(
          '/messages/$conversationId/pins',
        );
        if (messageId != null && context.mounted) context.pop(messageId);
      },
    );
  }
}
