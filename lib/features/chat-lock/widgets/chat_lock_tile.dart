import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/chat-details/details_tile.dart';
import '../../messages/chat_icon.dart';
import '../data/chat_lock_index.dart';
import '../providers/chat_locks_provider.dart';
import 'chat_lock_sheet.dart';

/// "Chat lock" on a DM's details screen; the value says how it opens.
class ChatLockTile extends ConsumerWidget {
  const ChatLockTile({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final method = ref.watch(chatLockMethodProvider(conversationId));
    return DetailsTile(
      icon: const ChatIcon(HugeIcons.strokeRoundedSquareLock02),
      title: t('chatlock_tile'),
      value: switch (method) {
        null => t('chatlock_opt_off'),
        ChatLockMethod.device => t('chatlock_opt_device'),
        ChatLockMethod.password => t('chatlock_opt_password'),
      },
      onTap: () => showChatLockSheet(context, ref, conversationId),
    );
  }
}
