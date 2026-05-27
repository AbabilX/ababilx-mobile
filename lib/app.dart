import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/notifications/fcm_handler.dart';

class AbabilXApp extends ConsumerStatefulWidget {
  const AbabilXApp({super.key});

  @override
  ConsumerState<AbabilXApp> createState() => _AbabilXAppState();
}

class _AbabilXAppState extends ConsumerState<AbabilXApp> {
  @override
  void initState() {
    super.initState();
    // Wire up FCM tap routing after first frame (router is available then)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final router = ref.read(routerProvider);
      FcmHandler.init(router);
      FcmHandler.handleInitialMessage(router);
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'AbabilX',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
