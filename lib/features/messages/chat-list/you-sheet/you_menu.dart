import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import 'you_menu_item.dart';
import 'you_sheet_action.dart';

/// Quick-action grid for the You sheet: Theme, Settings, QR Scanner, and Local Share.
class YouMenu extends ConsumerWidget {
  const YouMenu({super.key});

  static const _themeModeLabels = {
    ThemeMode.system: 'System',
    ThemeMode.light: 'Light',
    ThemeMode.dark: 'Dark',
  };

  List<List<dynamic>> _themeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return HugeIcons.strokeRoundedSun01;
      case ThemeMode.dark:
        return HugeIcons.strokeRoundedMoon02;
      case ThemeMode.system:
        return HugeIcons.strokeRoundedDarkMode;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final themeLabel = _themeModeLabels[themeMode] ?? 'Theme';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: YouMenuItem(
              icon: _themeIcon(themeMode),
              label: 'Theme',
              tooltip: 'Theme: $themeLabel',
              onTap: () => ref.read(themeModeProvider.notifier).cycle(),
            ),
          ),
          Expanded(
            child: YouMenuItem(
              icon: HugeIcons.strokeRoundedSettings02,
              label: 'Settings',
              tooltip: 'Settings',
              onTap: () {
                Navigator.pop(context);
                context.push('/settings');
              },
            ),
          ),
          Expanded(
            child: YouMenuItem(
              icon: HugeIcons.strokeRoundedQrCode,
              label: 'Scan QR',
              tooltip: 'Scan QR code',
              onTap: () {
                // Let the parent start scanning after this route finishes closing.
                // Pushing a second modal while this one is popping can leave the
                // navigator with a blank surface after a QR result is returned.
                Navigator.pop(context, YouSheetAction.scanQrLogin);
              },
            ),
          ),
          Expanded(
            child: YouMenuItem(
              icon: HugeIcons.strokeRoundedFolderTransfer,
              label: AppTranslations.translate(
                context,
                ref,
                'settings_local_share',
              ),
              tooltip: AppTranslations.translate(
                context,
                ref,
                'settings_local_share',
              ),
              onTap: () => Navigator.pop(context, YouSheetAction.localShare),
            ),
          ),
        ],
      ),
    );
  }
}
