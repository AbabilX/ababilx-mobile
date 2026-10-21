import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/chat_icon.dart';

enum StartNewChatChoice { google, skip }

/// Shown when Start New Chat is tapped, BEFORE any account exists: an
/// account with no Google or email is lost with the phone, so Google is
/// offered first. Skip goes on with a new account, nothing asked. Asking
/// first means choosing Google leaves no empty account behind on the server.
Future<StartNewChatChoice?> showStartNewChatSheet(BuildContext context) =>
    showModalBottomSheet<StartNewChatChoice>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _Sheet(),
    );

class _Sheet extends ConsumerWidget {
  const _Sheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    void pick(StartNewChatChoice choice) => Navigator.of(context).pop(choice);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: ChatIcon(
              HugeIcons.strokeRoundedShieldUser,
              size: 44,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            t('start_chat_sheet_title'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t('start_chat_sheet_body'),
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
            ),
            onPressed: () => pick(StartNewChatChoice.google),
            icon: ChatIcon(
              HugeIcons.strokeRoundedGoogle,
              size: 20,
              color: colors.onPrimary,
            ),
            label: Text(t('start_chat_sheet_google')),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
            ),
            onPressed: () => pick(StartNewChatChoice.skip),
            child: Text(t('start_chat_sheet_skip')),
          ),
        ],
      ),
    );
  }
}
