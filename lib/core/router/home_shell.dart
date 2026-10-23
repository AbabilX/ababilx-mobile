import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/calls/decline-message/decline_replies.dart';
import '../../features/messages/providers/chat_provider.dart';
import '../../features/local-backup/ui/local_backup_watcher.dart';
import '../../features/notifications/widgets/notification_vitals_watcher.dart';
import '../../features/policy/widgets/policy_gate_overlay.dart';
import '../../features/profile/providers/profile_provider.dart';
import '../../core/localization/app_translations.dart';
import '../../features/local_share/providers/share_quick_button.dart';
import '../../features/local_share/sheets/quick_button_sheet.dart';
import 'shell_bottom_bar/index.dart';
import 'shell_bottom_bar/nav_reorder_blur.dart';
import 'shell_bottom_bar/shell_chrome_provider.dart';
import 'shell_bottom_bar/shell_quick_button.dart';
import '../../features/settings/appearance/home_tab_setting.dart';
import 'shell_bottom_bar/shell_tab_order.dart';
import 'shell_bottom_bar/tab_reselect.dart';
import 'shell_bottom_bar/shell_tabs.dart';

/// Home shell: the routed page under the floating capsule nav.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A call shown from a push has no profile to read; its ringing screen's
    // reply texts use the language remembered here (written on change only).
    // Only a loaded profile counts: the 'en' fallback before it arrives must
    // not overwrite a remembered Bangla.
    // valueOrNull, never value: Riverpod 2 rethrows a failed profile load
    // from `.value`, and this is the shell. select: only the language.
    final profileLang = ref.watch(
      profileProvider.select((p) => p.valueOrNull?.appLanguage),
    );
    if (profileLang != null) {
      unawaited(DeclineReplies.rememberLanguage(profileLang.toLowerCase()));
    }
    final tabs = applyTabOrder(
      ref.watch(shownShellTabsProvider),
      ref.watch(shellTabOrderProvider),
    );
    final location = GoRouterState.of(context).matchedLocation;
    final idx = shellTabIndex(tabs, location);
    final unread = ref.watch(totalUnreadProvider);

    final Widget? bar = ref.watch(shellBottomBarHiddenProvider)
        ? null
        : ShellBottomBar(
            tabs: tabs,
            selectedIndex: idx,
            unread: unread,
            labelOf: (tab) =>
                AppTranslations.translate(context, ref, tab.labelKey),
            onSelect: (i) {
              if (i == idx) {
                // Tapping the tab you are on flips its filter: Chats between
                // All and Unread, Talk between All and Missed.
                signalTabReselect(ref, tabs[i].route);
              } else {
                context.go(tabs[i].route);
              }
            },
            quickButton: ref.watch(shareQuickButtonProvider)
                ? ShellQuickButton(
                    label: AppTranslations.translate(
                      context,
                      ref,
                      'settings_local_share',
                    ),
                    onTap: () => context.push('/local-share'),
                    onLongPress: () => unawaited(_removeSheet(context, ref)),
                  )
                : null,
            onReorder: (from, to) =>
                ref.read(shellTabOrderProvider.notifier).move(tabs, from, to),
          );

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: child),
          const NotificationVitalsWatcher(),
          const LocalBackupWatcher(),
          const PolicyGateOverlay(),
          const NavReorderBlur(),
          if (bar != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Material(type: MaterialType.transparency, child: bar),
            ),
        ],
      ),
    );
  }

  /// The bar steps aside while the sheet is up, or it would float over it.
  Future<void> _removeSheet(BuildContext context, WidgetRef ref) async {
    final hidden = ref.read(shellBottomBarHiddenProvider.notifier);
    hidden.state = true;
    try {
      await showQuickButtonSheet(context, ref);
    } finally {
      hidden.state = false;
    }
  }
}
