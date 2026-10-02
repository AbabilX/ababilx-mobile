import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/onboarding/onboarding_page.dart';
import '../../messages/chat_icon.dart';
import 'permission_intro.dart';

/// "Allow permissions" — Signal-Android's `GrantPermissionsScreen`: one row
/// per permission (48dp picture, title, why), Not now and Next at the foot.
///
/// Signal's pictures are its own colour illustrations (AGPL assets); these
/// rows use our Hugeicons in the accent colour instead.
class PermissionIntroPage extends ConsumerStatefulWidget {
  const PermissionIntroPage({
    super.key,
    required this.rows,
    required this.onDone,
  });

  final List<IntroPermission> rows;
  final VoidCallback onDone;

  @override
  ConsumerState<PermissionIntroPage> createState() => _State();
}

class _State extends ConsumerState<PermissionIntroPage> {
  bool _busy = false;

  Future<void> _answer(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    await action();
    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    return OnboardingPage(
      title: t('permissions_title'),
      subtitle: t('permissions_body'),
      bottom: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _busy ? null : () => _answer(PermissionIntro.later),
            child: Text(t('permissions_not_now')),
          ),
          const SizedBox(width: 24),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              minimumSize: const Size(96, 48),
              padding: const EdgeInsets.symmetric(horizontal: 28),
            ),
            onPressed: _busy
                ? null
                : () => _answer(() => PermissionIntro.grant(widget.rows)),
            child: Text(t('permissions_next')),
          ),
        ],
      ),
      children: [for (final row in widget.rows) _row(context, t, row)],
    );
  }

  Widget _row(
    BuildContext context,
    String Function(String) t,
    IntroPermission row,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (icon, title, body) = switch (row) {
      IntroPermission.notifications => (
        HugeIcons.strokeRoundedNotification03,
        'permissions_notifications',
        'permissions_notifications_body',
      ),
      IntroPermission.microphone => (
        HugeIcons.strokeRoundedMic01,
        'permissions_microphone',
        'permissions_microphone_body',
      ),
      IntroPermission.media => (
        HugeIcons.strokeRoundedImage01,
        'permissions_media',
        'permissions_media_body',
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 32, right: 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatIcon(icon, size: 48, color: colors.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t(title),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.onSurface,
                  ),
                ),
                Text(
                  t(body),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
