import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/launch/launch_hold.dart';
import 'core/router/app_router.dart';
import 'core/network/ws_link_watch.dart';
import 'core/router/root_back.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'features/messages/chat_store_sync.dart';
import 'features/notifications/fcm_bootstrap.dart';
import 'features/calls/call_store_sync.dart';
import 'features/calls/group/group_call_invite_host.dart';
import 'features/calls/group/group_call_sync.dart';
import 'features/calls/ongoing_call_sync.dart';
import 'features/ghost/ghost_sync.dart';
import 'features/app-update/app_update_gate.dart';
import 'features/calls/widgets/active_call_banner.dart';
import 'features/calls/widgets/call_lock_screen_host.dart';
import 'features/local_share/local_share_sync.dart';
import 'features/realtime/ws_background_release.dart';
import 'features/share_intake/direct-share/direct_share_sync.dart';
import 'features/share_intake/share_intake_sync.dart';

class AbabilXApp extends ConsumerWidget {
  const AbabilXApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final appThemeMode = ref.watch(themeModeProvider);

    final themeMode = switch (appThemeMode) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
      AppThemeMode.lightsOut => ThemeMode.dark,
    };

    final darkTheme = appThemeMode == AppThemeMode.lightsOut
        ? AppTheme.lightsOut
        : AppTheme.dark;

    return LaunchHoldRelease(
      child: FcmBootstrap(
        router: router,
        child: CallStoreSync(
          router: router,
          child: OngoingCallSync(
            router: router,
            child: GroupCallSync(
              router: router,
              child: LocalShareSync(
                child: ShareIntakeSync(
                  router: router,
                  child: DirectShareSync(
                    child: WsLinkWatch(
                      child: WsBackgroundRelease(
                        child: GhostSync(
                          router: router,
                          child: ChatStoreSync(
                            child: MaterialApp.router(
                              title: 'AbabilX',
                              debugShowCheckedModeBanner: false,
                              theme: AppTheme.light,
                              darkTheme: darkTheme,
                              themeMode: themeMode,
                              routerConfig: router,
                              // AppUpdateGate sits under the lock-screen host, so
                              // its cover over the keyguard stays on top.
                              builder: (context, child) => CallLockScreenHost(
                                router: router,
                                child: AppUpdateGate(
                                  child: RootBackScope(
                                    child: GroupCallInviteHost(
                                      child: ActiveCallBanner(
                                        router: router,
                                        child: child ?? const SizedBox.shrink(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
