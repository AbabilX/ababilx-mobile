import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/messages/chat_store_sync.dart';
import 'features/notifications/fcm_bootstrap.dart';
import 'features/calls/call_store_sync.dart';

class AbabilXApp extends ConsumerWidget {
  const AbabilXApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return FcmBootstrap(
      router: router,
      child: CallStoreSync(
        router: router,
        child: ChatStoreSync(
          child: MaterialApp.router(
            title: 'AbabilX',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: ThemeMode.system,
            routerConfig: router,
          ),
        ),
      ),
    );
  }
}
