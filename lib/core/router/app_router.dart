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
import 'home_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull ?? false;
      final isLoading = authState.isLoading;

      if (isLoading) return null; // Stay on current screen while loading

      final isLoginPage = state.matchedLocation == '/login';

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
});
