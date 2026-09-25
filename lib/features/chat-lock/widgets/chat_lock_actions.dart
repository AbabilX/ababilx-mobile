import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/chat_lock_index.dart';
import '../native/device_auth.dart';
import '../providers/chat_locks_provider.dart';
import 'chat_lock_password_sheet.dart';

/// Proves the person holding the phone may open or change this chat's lock,
/// by the lock's own method. True for a chat that is not locked.
Future<bool> verifyChatLock(
  BuildContext context,
  WidgetRef ref,
  String conversationId,
) async {
  String t(String key) => AppTranslations.translate(context, ref, key);
  final method = ref.read(chatLockMethodProvider(conversationId));
  if (method == null) return true;
  if (method == ChatLockMethod.device) {
    final result = await DeviceAuth.authenticate(
      title: t('chatlock_prompt_title'),
    );
    if (result == DeviceAuthResult.unavailable && context.mounted) {
      showAppToast(context, t('chatlock_no_screen_lock'), isError: true);
    }
    return result == DeviceAuthResult.ok;
  }
  final password = await askChatLockPassword(context, ref);
  if (password == null) return false;
  final ok = await ref
      .read(chatLocksProvider.notifier)
      .verifyPassword(conversationId, password);
  if (!ok && context.mounted) {
    showAppToast(context, t('chatlock_pw_wrong'), isError: true);
  }
  return ok;
}

/// "Forgot password?": the phone's own lock stands in for the chat's
/// password, then a new one is set. Without a screen lock there is nothing
/// to stand in, and the person is told to set one — which anyone holding
/// an unlocked phone could do, so it opens nothing new.
Future<bool> resetChatLockPassword(
  BuildContext context,
  WidgetRef ref,
  String conversationId,
) async {
  String t(String key) => AppTranslations.translate(context, ref, key);
  final result = await DeviceAuth.authenticate(
    title: t('chatlock_reset_title'),
  );
  if (!context.mounted) return false;
  if (result == DeviceAuthResult.unavailable) {
    showAppToast(context, t('chatlock_reset_needs_screen_lock'), isError: true);
    return false;
  }
  if (result != DeviceAuthResult.ok) return false;
  final password = await askNewChatLockPassword(context, ref);
  if (password == null) return false;
  await ref
      .read(chatLocksProvider.notifier)
      .lockWithPassword(conversationId, password);
  return true;
}
