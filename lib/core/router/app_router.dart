import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/providers/profile_provider.dart';

/// Re-evaluates GoRouter redirects when auth changes without recreating the router.
class _RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final _routerRefreshNotifierProvider = Provider<_RouterRefreshNotifier>((ref) {
  final notifier = _RouterRefreshNotifier();
  ref.listen(authProvider, (previous, next) {
    notifier.refresh();

    final wasLoggedIn = previous?.valueOrNull ?? false;
    final isLoggedIn = next.valueOrNull ?? false;
    if (wasLoggedIn == isLoggedIn) return;

    // Login/logout complete — refetch profile with the new session.
    ref.invalidate(profileProvider);
  });
  ref.onDispose(notifier.dispose);
  return notifier;
});

final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = ref.watch(_routerRefreshNotifierProvider);

  final router = GoRouter(
    initialLocation: '/login',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isLoggedIn = authState.valueOrNull ?? false;
      final isLoading = authState.isLoading;
      final isLoginPage = state.matchedLocation == '/login';

      // Auth in progress: keep login screen during sign-in; block app until ready.
      if (isLoading) {
        if (isLoginPage) return null;
        return '/login';
      }

      if (!isLoggedIn && !isLoginPage) return '/login';
      if (isLoggedIn && isLoginPage) return '/profile';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, _) => const ProfileScreen(),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(
        child: Text(
          'Page not found: ${state.error}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    ),
  );

  ref.onDispose(router.dispose);
  return router;
});
