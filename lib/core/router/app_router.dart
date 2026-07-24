import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/providers/profile_provider.dart';
import '../../features/messages/providers/team_gate_provider.dart';
import '../../features/messages/screens/messages_screen.dart';
import '../../features/messages/screens/conversation_screen.dart';
import '../../features/wall/screens/wall_screen.dart';
import '../../features/wall/screens/wall_post_screen.dart';
import '../../features/crm/screens/crm_hub_screen.dart';
import '../../features/crm/screens/crm_contacts_screen.dart';
import 'home_shell.dart';

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
    ref.invalidate(profileProvider);
    ref.invalidate(teamGateProvider);
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

      if (isLoading) {
        if (isLoginPage) return null;
        return '/login';
      }

      if (!isLoggedIn && !isLoginPage) return '/login';
      if (isLoggedIn && isLoginPage) return '/messages';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, _) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (_, _, child) => HomeShell(child: child),
        routes: [
          GoRoute(
            path: '/messages',
            builder: (_, _) => const MessagesScreen(),
          ),
          GoRoute(
            path: '/wall',
            builder: (_, _) => const WallScreen(),
          ),
          GoRoute(
            path: '/crm',
            builder: (_, _) => const CrmHubScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, _) => const ProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/messages/:id',
        builder: (_, state) => ConversationScreen(
          conversationId: state.pathParameters['id']!,
          threadRootId: state.uri.queryParameters['thread'],
        ),
      ),
      GoRoute(
        path: '/wall/post/:postId',
        builder: (_, state) => WallPostScreen(
          postId: state.pathParameters['postId']!,
        ),
      ),
      GoRoute(
        path: '/crm/contacts',
        builder: (_, _) => const CrmContactsScreen(),
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
