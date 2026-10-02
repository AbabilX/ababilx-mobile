import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/chat_icon.dart';

/// Shown once a chat is newly locked: the chat has just left the list, and
/// nothing on screen says where it went. Names both ways back — holding the
/// AbabilX title, and Settings → Locked chats — so a person who never learns
/// the gesture is not locked out of their own chat.
Future<void> showChatLockFoundSheet(BuildContext context, WidgetRef ref) {
  String t(String key) => AppTranslations.translate(context, ref, key);
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (sheet) {
      final theme = Theme.of(sheet);
      final colors = theme.colorScheme;
      Widget way(List<List<dynamic>> icon, String title, String subtitle) =>
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: ChatIcon(icon, color: colors.onSurfaceVariant),
            title: Text(title),
            subtitle: Text(subtitle),
          );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ChatIcon(
                  HugeIcons.strokeRoundedSquareLock02,
                  size: 40,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                t('chatlock_found_title'),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                t('chatlock_found_body'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              way(
                HugeIcons.strokeRoundedTouch01,
                t('chatlock_found_hold'),
                t('chatlock_found_hold_sub'),
              ),
              way(
                HugeIcons.strokeRoundedSettings02,
                t('chatlock_found_settings'),
                t('chatlock_found_settings_sub'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(sheet),
                child: Text(t('chatlock_found_ok')),
              ),
            ],
          ),
        ),
      );
    },
  );
}
