import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../presence/online_presence_provider.dart';
import '../../../privacy-mode/privacy_mode_provider.dart';
import 'you_away.dart';
import 'you_menu_item.dart';
import 'you_sheet_action.dart';

/// The You sheet's two rows.
///
/// Top row = switches that act in place and show their state (lit when on):
/// Away · Privacy · Theme, then People (the screen you
/// most often want next). Bottom row = places that close the sheet: Scan QR and
/// Devices together (scanning is how a device gets linked), Local Share, and
/// Settings last as the catch-all.
class YouMenu extends ConsumerWidget {
  const YouMenu({super.key});

  static const _themeModeLabels = {
    AppThemeMode.system: 'System',
    AppThemeMode.light: 'Light',
    AppThemeMode.dark: 'Dark',
    AppThemeMode.lightsOut: 'Lights Out',
  };

  List<List<dynamic>> _themeIcon(AppThemeMode mode) => switch (mode) {
    AppThemeMode.light => HugeIcons.strokeRoundedSun01,
    AppThemeMode.dark => HugeIcons.strokeRoundedMoon02,
    AppThemeMode.system => HugeIcons.strokeRoundedDarkMode,
    AppThemeMode.lightsOut => HugeIcons.strokeRoundedMoonEclipse,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String tr(String key) => AppTranslations.translate(context, ref, key);
    final themeMode = ref.watch(themeModeProvider);
    final themeLabel = _themeModeLabels[themeMode] ?? 'Theme';
    final away = ref.watch(awayProvider);
    final private = ref.watch(privacyModeProvider);

    void go(String path) {
      Navigator.pop(context);
      context.push(path);
    }

    Future<void> flipAway() async {
      final ok = await ref.read(awayProvider.notifier).set(!away);
      // Away sees nobody online either; the server's empty roster follows.
      if (ok && !away) ref.read(onlinePresenceProvider.notifier).clear();
      if (!ok && context.mounted) showAppToast(context, tr('you_away_failed'));
    }

    Future<void> flipPrivacy() async {
      final ok = await ref.read(privacyModeProvider.notifier).set(!private);
      if (!ok && context.mounted) {
        showAppToast(context, tr('privacy_mode_save_failed'));
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          _row([
            YouMenuItem(
              icon: HugeIcons.strokeRoundedMoon01,
              label: tr('you_away'),
              tooltip: tr('you_away_tip'),
              active: away,
              onTap: flipAway,
            ),
            YouMenuItem(
              icon: HugeIcons.strokeRoundedShield01,
              label: tr('you_privacy'),
              tooltip: tr('privacy_mode_title'),
              active: private,
              onTap: flipPrivacy,
            ),
            YouMenuItem(
              icon: _themeIcon(themeMode),
              label: themeLabel,
              tooltip: 'Theme: $themeLabel',
              onTap: () => ref.read(themeModeProvider.notifier).cycle(),
            ),
            YouMenuItem(
              icon: HugeIcons.strokeRoundedUserMultiple,
              label: tr('chat_people'),
              tooltip: tr('chat_people'),
              onTap: () => go('/messages/people'),
            ),
          ]),
          const SizedBox(height: 4),
          _row([
            YouMenuItem(
              icon: HugeIcons.strokeRoundedQrCode,
              label: tr('you_scan_qr'),
              tooltip: tr('you_scan_qr'),
              // The parent starts scanning once this route has closed:
              // pushing a modal while this one pops can leave a blank surface.
              onTap: () => Navigator.pop(context, YouSheetAction.scanQrLogin),
            ),
            YouMenuItem(
              icon: HugeIcons.strokeRoundedLaptopPhoneSync,
              label: tr('you_devices'),
              tooltip: tr('you_devices_tip'),
              onTap: () => go('/profile/devices'),
            ),
            YouMenuItem(
              icon: HugeIcons.strokeRoundedFolderTransfer,
              label: tr('settings_local_share'),
              tooltip: tr('settings_local_share'),
              onTap: () => Navigator.pop(context, YouSheetAction.localShare),
            ),
            YouMenuItem(
              icon: HugeIcons.strokeRoundedSettings02,
              label: tr('you_settings'),
              tooltip: tr('you_settings'),
              onTap: () => go('/settings'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _row(List<Widget> items) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [for (final item in items) Expanded(child: item)],
  );
}
