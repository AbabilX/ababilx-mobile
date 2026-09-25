import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../chat-lock/providers/chat_locks_provider.dart';
import '../../messages/chat-details/details_tile.dart';
import '../../messages/chat_icon.dart';
import '../../notifications/chat/chat_notification_ids.dart';
import '../../notifications/chat/chat_notification_privacy.dart';
import '../../notifications/chat/chat_notification_store.dart';
import '../../notifications/providers/fcm_provider.dart';

/// The DMs whose notifications the user set to hide name and text, not
/// counting locked ones (those always hide). Device-local.
class HiddenNotificationText extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() => ChatNotificationPrivacy.chosen();

  Future<void> set(String conversationId, bool hidden) async {
    await ChatNotificationPrivacy.setChosen(conversationId, hidden);
    state = AsyncData(await ChatNotificationPrivacy.chosen());
    if (!hidden) return;
    // An entry already in the shade still shows the old text.
    await ChatNotificationStore.clear(conversationId);
    await ref
        .read(localNotificationsProvider)
        .cancel(chatNotificationId(conversationId));
  }
}

final hiddenNotificationTextProvider =
    AsyncNotifierProvider<HiddenNotificationText, Set<String>>(
      HiddenNotificationText.new,
    );

/// "Hide notification text" on a DM's details screen. A locked chat shows it
/// on and fixed: the lock would be pointless with the messages in the shade.
class HideNotificationTextTile extends ConsumerWidget {
  const HideNotificationTextTile({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final locked = ref.watch(isChatLockedProvider(conversationId));
    final chosen =
        ref
            .watch(hiddenNotificationTextProvider)
            .valueOrNull
            ?.contains(conversationId) ??
        false;
    final on = locked || chosen;
    void flip(bool value) => ref
        .read(hiddenNotificationTextProvider.notifier)
        .set(conversationId, value);
    return DetailsTile(
      icon: const ChatIcon(HugeIcons.strokeRoundedNotificationSquare),
      title: t('dm_hide_notif_text'),
      value: locked
          ? t('dm_hide_notif_text_locked')
          : on
          ? t('dm_hide_notif_text_on')
          : t('dm_hide_notif_text_off'),
      onTap: locked ? null : () => flip(!chosen),
      trailing: Switch(value: on, onChanged: locked ? null : flip),
    );
  }
}
