import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/chat_icon.dart';

/// Privacy mode is on, so no code is drawn: the server answers a scan of this
/// account's handle with "no such account" (server migration 0152), and a
/// code that leads nowhere is worse than none.
class MyQrPrivate extends ConsumerWidget {
  const MyQrPrivate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    String tr(String key) => AppTranslations.translate(context, ref, key);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChatIcon(
              HugeIcons.strokeRoundedShield01,
              size: 72,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 20),
            Text(
              tr('privacy_mode_qr_title'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr('privacy_mode_qr_body'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => context.push('/settings/privacy-mode'),
              child: Text(tr('privacy_mode_title')),
            ),
          ],
        ),
      ),
    );
  }
}
