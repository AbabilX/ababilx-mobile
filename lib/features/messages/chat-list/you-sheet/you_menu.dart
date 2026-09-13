import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../chat_icon.dart';
import 'you_menu_item.dart';
import 'you_sheet_action.dart';

class YouMenu extends ConsumerWidget {
  const YouMenu({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: colors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: colors.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ChatIcon(
                  HugeIcons.strokeRoundedLogout01,
                  color: colors.error,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppTranslations.translate(context, ref, 'sign_out'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppTranslations.translate(context, ref, 'confirm_signout'),
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogCtx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.onSurface,
                        side: BorderSide(color: colors.outline),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        AppTranslations.translate(context, ref, 'cancel'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(dialogCtx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.error,
                        foregroundColor: colors.onError,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        AppTranslations.translate(context, ref, 'sign_out'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;
    // Read the notifier BEFORE the pop. Closing the sheet disposes this
    // widget, and a disposed `ref` asserts — which only fires in debug, since
    // release strips asserts. That is why signing out worked in a release
    // build and silently did nothing in a debug one.
    final auth = ref.read(authProvider.notifier);
    if (context.mounted) Navigator.pop(context); // close You sheet first
    await auth.signOut();
  }

  static const _themeModeLabels = {
    ThemeMode.system: 'System',
    ThemeMode.light: 'Light',
    ThemeMode.dark: 'Dark',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        YouMenuItem(
          icon: HugeIcons.strokeRoundedDarkMode,
          label: 'Theme',
          onTap: () => ref.read(themeModeProvider.notifier).cycle(),
          trailing: Text(
            _themeModeLabels[themeMode]!,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
          ),
        ),
        YouMenuItem(
          icon: HugeIcons.strokeRoundedSettings02,
          label: 'Settings',
          onTap: () {
            Navigator.pop(context);
            context.push('/settings');
          },
        ),
        YouMenuItem(
          icon: HugeIcons.strokeRoundedQrCode,
          // One scanner, two jobs: a sign-in code and a message-link code. The
          // label says neither, because naming only sign-in hides the link
          // path from the person told to scan from the device that has their
          // messages.
          label: 'Scan QR code',
          onTap: () {
            // Let the parent start scanning after this route finishes closing.
            // Pushing a second modal while this one is popping can leave the
            // navigator with a blank surface after a QR result is returned.
            Navigator.pop(context, YouSheetAction.scanQrLogin);
          },
        ),
        YouMenuItem(
          icon: HugeIcons.strokeRoundedFolderTransfer,
          label: 'Local Share',
          onTap: () => Navigator.pop(context, YouSheetAction.localShare),
        ),
        YouMenuItem(
          icon: HugeIcons.strokeRoundedLogout01,
          // "Sign out" — this ends the account session on the device, not a
          // workspace membership. The old wording read as leaving a team.
          label: 'Sign out',
          onTap: () => _signOut(context, ref),
        ),
      ],
    );
  }
}
