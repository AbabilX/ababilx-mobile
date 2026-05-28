import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/rules/screens/rules_screen.dart';
import '../../features/rules/screens/rule_form_screen.dart';
import '../../features/rules/screens/rule_history_screen.dart';
import '../../features/rules/screens/message_preview_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/auto_commit/screens/auto_commit_screen.dart';
import '../../features/auto_commit/screens/auto_commit_form_screen.dart';
import '../../features/auto_commit/providers/auto_commit_provider.dart';
import '../../features/home/providers/activity_provider.dart';
import '../../features/profile/providers/profile_provider.dart';
import '../../features/rules/providers/rules_provider.dart';
import 'home_shell.dart';

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

    // Login/logout complete — refetch user data with the new session.
    ref.invalidate(profileProvider);
    ref.invalidate(rulesProvider);
    ref.invalidate(autoCommitProvider);
    ref.invalidate(activityProvider);
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

      // Auth in progress: keep login screen during sign-in; block home until ready.
      if (isLoading) {
        if (isLoginPage) return null;
        return '/login';
      }

      if (!isLoggedIn && !isLoginPage) return '/login';
      if (isLoggedIn && isLoginPage) return '/home';
      return null;
    },
    routes: [
      // ── Login ──────────────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        builder: (_, _) => const LoginScreen(),
      ),

      // ── Home shell (bottom nav: Home + Rules + Auto-Commit + Profile) ───
      ShellRoute(
        builder: (_, _, child) => HomeShell(child: child),
        routes: [
          // Overview / Home
          GoRoute(
            path: '/home',
            builder: (_, _) => const HomeScreen(),
          ),

          // Rules list
          GoRoute(
            path: '/rules',
            builder: (_, _) => const RulesScreen(),
            routes: [
              // Create rule
              GoRoute(
                path: 'new',
                builder: (_, _) => const RuleFormScreen(),
              ),
              // Rule-specific routes
              GoRoute(
                path: ':id',
                routes: [
                  // Edit rule
                  GoRoute(
                    path: 'edit',
                    builder: (_, state) =>
                        RuleFormScreen(ruleId: state.pathParameters['id']),
                  ),
                  // Message history
                  GoRoute(
                    path: 'history',
                    builder: (_, state) => RuleHistoryScreen(
                      ruleId: state.pathParameters['id']!,
                    ),
                  ),
                  // Pre-send preview (notification deep-link)
                  GoRoute(
                    path: 'preview',
                    builder: (_, state) => MessagePreviewScreen(
                      ruleId: state.pathParameters['id']!,
                      fromNotification:
                          state.uri.queryParameters['fromNotification'] ==
                              'true',
                    ),
                  ),
                ],
                // Redirect /rules/:id → /rules/:id/edit for tap on rule card
                builder: (_, state) =>
                    RuleFormScreen(ruleId: state.pathParameters['id']),
              ),
            ],
          ),

          // Auto-commit jobs
          GoRoute(
            path: '/auto-commit',
            builder: (_, _) => const AutoCommitScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, _) => const AutoCommitFormScreen(),
              ),
              GoRoute(
                path: ':id/edit',
                builder: (_, state) =>
                    AutoCommitFormScreen(jobId: state.pathParameters['id']),
              ),
            ],
          ),

          // Profile
          GoRoute(
            path: '/profile',
            builder: (_, _) => const ProfileScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.error}',
            style: const TextStyle(color: Colors.white)),
      ),
    ),
  );

  ref.onDispose(router.dispose);
  return router;
});
