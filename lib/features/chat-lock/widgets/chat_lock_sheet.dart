import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../messages/chat_icon.dart';
import '../data/chat_lock_index.dart';
import '../native/device_auth.dart';
import '../providers/chat_locks_provider.dart';
import 'chat_lock_actions.dart';
import 'chat_lock_password_sheet.dart';

enum _Choice { off, device, password }

/// Chat lock for one DM: off, the phone's own lock, or a password for this
/// chat alone. Changing or removing a lock asks for the current one first —
/// the details screen being open is not proof enough, it may have been left
/// open.
Future<void> showChatLockSheet(
  BuildContext context,
  WidgetRef ref,
  String conversationId,
) async {
  final current = ref.read(chatLockMethodProvider(conversationId));
  final phoneLock = await DeviceAuth.available();
  if (!context.mounted) return;
  String t(String key) => AppTranslations.translate(context, ref, key);
  final choice = await showModalBottomSheet<_Choice>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (sheet) {
      Widget option(
        _Choice value,
        List<List<dynamic>> icon,
        String title,
        String subtitle, {
        bool enabled = true,
      }) {
        final selected = switch (value) {
          _Choice.off => current == null,
          _Choice.device => current == ChatLockMethod.device,
          _Choice.password => current == ChatLockMethod.password,
        };
        return ListTile(
          enabled: enabled,
          leading: ChatIcon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: selected
              ? const ChatIcon(HugeIcons.strokeRoundedTick02)
              : null,
          onTap: () => Navigator.of(sheet).pop(value),
        );
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            option(
              _Choice.off,
              HugeIcons.strokeRoundedSquareUnlock02,
              t('chatlock_opt_off'),
              t('chatlock_opt_off_sub'),
            ),
            option(
              _Choice.device,
              HugeIcons.strokeRoundedFingerPrint,
              t('chatlock_opt_device'),
              t(
                phoneLock
                    ? 'chatlock_opt_device_sub'
                    : 'chatlock_no_screen_lock',
              ),
              enabled: phoneLock,
            ),
            option(
              _Choice.password,
              HugeIcons.strokeRoundedLockPassword,
              current == ChatLockMethod.password
                  ? t('chatlock_opt_password_change')
                  : t('chatlock_opt_password'),
              t('chatlock_opt_password_sub'),
            ),
          ],
        ),
      );
    },
  );
  if (choice == null || !context.mounted) return;
  await _apply(context, ref, conversationId, current, choice);
}

Future<void> _apply(
  BuildContext context,
  WidgetRef ref,
  String conversationId,
  ChatLockMethod? current,
  _Choice choice,
) async {
  String t(String key) => AppTranslations.translate(context, ref, key);
  final locks = ref.read(chatLocksProvider.notifier);
  if (choice == _Choice.off && current == null) return;
  if (choice == _Choice.device && current == ChatLockMethod.device) return;
  if (current != null && !await verifyChatLock(context, ref, conversationId)) {
    return;
  }
  if (!context.mounted) return;
  switch (choice) {
    case _Choice.off:
      await locks.removeLock(conversationId);
      if (context.mounted) showAppToast(context, t('chatlock_removed'));
    case _Choice.device:
      // Asked once now, so a phone whose prompt cannot finish is found out
      // here and not at the first attempt to open the chat.
      final result = await DeviceAuth.authenticate(
        title: t('chatlock_prompt_title'),
      );
      if (result != DeviceAuthResult.ok) return;
      await locks.lockWithDevice(conversationId);
      if (context.mounted) showAppToast(context, t('chatlock_on'));
    case _Choice.password:
      final password = await askNewChatLockPassword(context, ref);
      if (password == null) return;
      await locks.lockWithPassword(conversationId, password);
      if (context.mounted) showAppToast(context, t('chatlock_on'));
  }
}
