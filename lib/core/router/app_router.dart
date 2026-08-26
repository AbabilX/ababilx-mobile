import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/board/screens/board_screen.dart';
import '../../features/board/screens/board_detail_screen.dart';
import '../../features/board/screens/board_task_detail_screen.dart';
import '../../features/profile/screens/sessions_screen.dart';
import '../../features/profile/providers/profile_provider.dart';
import '../../features/messages/providers/team_gate_provider.dart';
import '../../features/messages/screens/messages_screen.dart';
import '../../features/messages/screens/conversation_screen.dart';
import '../../features/messages/screens/people_screen.dart';
import '../../features/messages/screens/new_message_screen.dart';
import '../../features/wall/screens/wall_screen.dart';
import '../../features/wall/screens/wall_post_screen.dart';
import '../../features/crm/screens/crm_hub_screen.dart';
import '../../features/crm/screens/crm_contacts_screen.dart';
import '../../features/crm/screens/crm_leads_screen.dart';
import '../../features/crm/screens/crm_lead_detail_screen.dart';
import '../../features/crm/screens/crm_followups_screen.dart';
import '../../features/crm/screens/crm_followup_detail_screen.dart';
import '../../features/crm/screens/crm_contact_detail_screen.dart';
import '../../features/crm/screens/crm_organizations_screen.dart';
import '../../features/crm/screens/crm_organization_detail_screen.dart';
import '../../features/calls/group/screens/group_call_screen.dart';
import '../../features/calls/screens/calls_screen.dart';
import '../../features/calls/screens/voice_call_screen.dart';
import '../../features/local_share/screens/local_share_screen.dart';
import '../../features/settings/screens/notification_settings_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import 'home_shell.dart';

/// Root navigator key — lets app-wide listeners (incoming call, incoming
/// local-share request) show UI on top of whatever screen is current.
final rootNavigatorKey = GlobalKey<NavigatorState>();

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
    navigatorKey: rootNavigatorKey,
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
      if (isLoggedIn && isLoginPage) {
        // Always land on Messages first. FcmService.flushPendingNav seeds
        // the deep-link (push) so Android back returns here instead of exit.
        return '/messages';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      ShellRoute(
        builder: (_, _, child) => HomeShell(child: child),
        routes: [
          GoRoute(path: '/messages', builder: (_, _) => const MessagesScreen()),
          GoRoute(path: '/calls', builder: (_, _) => const CallsScreen()),
          GoRoute(path: '/wall', builder: (_, _) => const WallScreen()),
          GoRoute(
            path: '/crm/organizations',
            builder: (_, _) => const CrmOrganizationsScreen(),
          ),
          GoRoute(
            path: '/crm/contacts',
            builder: (_, _) => const CrmContactsScreen(),
          ),
          GoRoute(
            path: '/crm/leads',
            builder: (_, state) =>
                CrmLeadsScreen(contactId: state.uri.queryParameters['contact']),
          ),
          GoRoute(
            path: '/crm/followups',
            builder: (_, _) => const CrmFollowupsScreen(),
          ),
          GoRoute(path: '/crm', builder: (_, _) => const CrmHubScreen()),
          GoRoute(path: '/board', builder: (_, _) => const BoardScreen()),
        ],
      ),
      GoRoute(path: '/call', builder: (_, _) => const VoiceCallScreen()),
      GoRoute(path: '/group-call', builder: (_, _) => const GroupCallScreen()),
      GoRoute(
        path: '/local-share',
        builder: (_, _) => const LocalShareScreen(),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(
        path: '/settings/notifications',
        builder: (_, _) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '/profile/devices',
        builder: (_, _) => const SessionsScreen(),
      ),
      GoRoute(
        path: '/messages/people',
        builder: (_, _) => const PeopleScreen(),
      ),
      GoRoute(
        path: '/messages/new',
        builder: (_, _) => const NewMessageScreen(),
      ),
      GoRoute(
        path: '/messages/:id',
        builder: (_, state) => ConversationScreen(
          conversationId: state.pathParameters['id']!,
          threadRootId: state.uri.queryParameters['thread'],
        ),
      ),
      GoRoute(
        path: '/board/:boardId/tasks/:taskId',
        builder: (_, state) => BoardTaskDetailScreen(
          boardId: state.pathParameters['boardId']!,
          taskId: state.pathParameters['taskId']!,
        ),
      ),
      GoRoute(
        path: '/board/:boardId',
        builder: (_, state) => BoardDetailScreen(
          boardId: state.pathParameters['boardId']!,
          taskId: state.uri.queryParameters['taskId'],
        ),
      ),
      GoRoute(
        path: '/wall/post/:postId',
        builder: (_, state) =>
            WallPostScreen(postId: state.pathParameters['postId']!),
      ),
      GoRoute(
        path: '/crm/organizations/:id',
        builder: (_, state) => CrmOrganizationDetailScreen(
          organizationId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/crm/leads/:id',
        builder: (_, state) =>
            CrmLeadDetailScreen(leadId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/crm/contacts/:id',
        builder: (_, state) =>
            CrmContactDetailScreen(contactId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/crm/followups/:id',
        builder: (_, state) =>
            CrmFollowupDetailScreen(followupId: state.pathParameters['id']!),
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
