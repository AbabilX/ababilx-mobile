import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/chat-lock/screens/locked_chats_screen.dart';
import '../../features/chat-lock/widgets/chat_lock_gate.dart';
import '../../features/ghost/screens/ghost_chat_screen.dart';
import '../../features/ghost/screens/ghost_invite_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/email/email_auth_routes.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/profile/screens/sessions_screen.dart';
import '../../features/profile/providers/profile_provider.dart';
import '../../features/messages/wallpaper/chat_wallpaper_screen.dart';
import '../../features/settings/app-icon/app_icon_screen.dart';
import '../../features/messages/chat-details/conversation_details_screen.dart';
import '../../features/messages/chat-details/group_members_screen.dart';
import '../../features/messages/data/models/chat_models.dart';
import '../../features/messages/group-member-permissions/group_permissions_screen.dart';
import '../../features/messages/group-member-permissions/member_permissions_route.dart';
import '../../features/messages/chat-pins/pinned_messages_screen.dart';
import '../../features/messages/chat-media/conversation_media_screen.dart';
import '../../features/messages/screens/conversation_screen.dart';
import '../../features/messages/screens/connections_screen.dart';
import '../../features/messages/screens/find_people_screen.dart';
import '../../features/messages/screens/people_screen.dart';
import '../../features/messages/screens/new_message_screen.dart';
import '../../features/calls/group/screens/group_call_lobby_screen.dart';
import '../../features/calls/group/screens/group_call_screen.dart';
import '../../features/calls/call-info/call_info_path.dart';
import '../../features/calls/call-info/call_info_screen.dart';
import '../../features/calls/screens/voice_call_screen.dart';
import '../../features/local_share/screens/local_share_screen.dart';
import '../../features/local_share/screens/local_share_thread_screen.dart';
import '../../features/settings/chat-backup/chat_backup_screen.dart';
import '../../features/local-backup/ui/local_backup_screen.dart';
import '../../features/settings/data-storage/chat_lock_settings_screen.dart';
import '../../features/settings/data-storage/data_storage_screen.dart';
import '../../features/settings/data-storage/storage_management_screen.dart';
import '../../features/settings/data-storage/storage_review_screen.dart';
import '../../features/settings/screens/media_quality_screen.dart';
import '../../features/settings/screens/notification_settings_screen.dart';
import '../../features/settings/screens/discovery_screen.dart';
import '../../features/privacy-mode/people/privacy_people_screen.dart';
import '../../features/privacy-mode/privacy_mode_screen.dart';
import '../../features/settings/screens/edit_name_screen.dart';
import '../../features/settings/screens/edit_username_screen.dart';
import '../../features/settings/screens/my_qr_screen.dart';
import '../../features/share_intake/screens/share_target_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import 'home_shell.dart';
import 'home_tab_pager.dart';
import '../../features/settings/recovery-codes/recovery_codes_screen.dart';
import '../../features/messages/message_e2ee/message_entry_ready.dart';
import '../../features/messages/message_e2ee/message_recovery_screen.dart';
import '../../features/onboarding/permissions/permission_intro_gate.dart';

/// Root navigator key — lets app-wide listeners (incoming call, incoming
/// local-share request) show UI on top of whatever screen is current.
final rootNavigatorKey = GlobalKey<NavigatorState>();

class _RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final _routerRefreshNotifierProvider = Provider<_RouterRefreshNotifier>((ref) {
  final notifier = _RouterRefreshNotifier();
  ref.listen(messageEntryReadyProvider, (_, _) => notifier.refresh());
  ref.listen(authProvider, (previous, next) {
    notifier.refresh();
    final wasLoggedIn = previous?.valueOrNull ?? false;
    final isLoggedIn = next.valueOrNull ?? false;
    if (wasLoggedIn == isLoggedIn) return;
    // Only a sign-out clears it: a launch sets it during auth's own load
    // (tryQuietMessageEntry), and clearing on that transition would undo it.
    if (!isLoggedIn) ref.read(messageEntryReadyProvider.notifier).state = false;
    ref.invalidate(profileProvider);
  });
  ref.onDispose(notifier.dispose);
  return notifier;
});

/// A call screen appears at once. On a locked phone a slide-in would paint the
/// route underneath over the keyguard for its whole length — see
/// `CallLockScreenGuard`.
GoRouterPageBuilder _instant(Widget child) =>
    (_, state) => NoTransitionPage(key: state.pageKey, child: child);

final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = ref.watch(_routerRefreshNotifierProvider);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    // Blank, behind the held splash (LaunchHold) until auth has read the
    // saved session; never the login picture on a signed-in launch.
    initialLocation: '/launch',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isLoggedIn = authState.valueOrNull ?? false;
      final isLoading = authState.isLoading;
      // The email sign-in steps live under /login, so a signed-out user may
      // move between them and a finished sign-in leaves all of them at once.
      final location = state.matchedLocation;
      final isLoginPage =
          location == '/login' || location.startsWith('/login/');

      final isLaunch = location == '/launch';
      if (isLoading) {
        if (isLoginPage || isLaunch) return null;
        return '/launch';
      }

      if (!isLoggedIn && !isLoginPage) return '/login';
      if (isLoggedIn && !ref.read(messageEntryReadyProvider)) {
        return state.matchedLocation == '/message-recovery'
            ? null
            : '/message-recovery';
      }
      if (isLoggedIn &&
          (isLoginPage ||
              isLaunch ||
              state.matchedLocation == '/message-recovery')) {
        // Always land on Messages first. FcmService.flushPendingNav seeds
        // the deep-link (push) so Android back returns here instead of exit.
        return '/messages';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/launch', pageBuilder: _instant(const Scaffold())),
      GoRoute(
        path: '/login',
        builder: (_, _) => const LoginScreen(),
        routes: emailAuthRoutes,
      ),
      GoRoute(
        path: '/message-recovery',
        builder: (_, _) =>
            const PermissionIntroGate(child: MessageRecoveryScreen()),
      ),
      ShellRoute(
        builder: (_, _, child) => HomeShell(child: child),
        routes: [
          // One page for both, so a swipe moves between them.
          GoRoute(
            path: '/messages',
            pageBuilder: (_, state) => homeTabPage(state, 0),
          ),
          GoRoute(
            path: '/calls',
            pageBuilder: (_, state) => homeTabPage(state, 1),
          ),
        ],
      ),
      GoRoute(path: '/call', pageBuilder: _instant(const VoiceCallScreen())),
      // Ghost Chat. `GhostSync` is the only thing that pushes or pops these.
      GoRoute(path: '/ghost', builder: (_, _) => const GhostChatScreen()),
      GoRoute(
        path: '/ghost/invite',
        pageBuilder: _instant(const GhostInviteScreen()),
      ),
      GoRoute(
        path: '/group-call',
        pageBuilder: _instant(const GroupCallScreen()),
      ),
      GoRoute(
        path: '/group-call/lobby',
        builder: (_, _) => const GroupCallLobbyScreen(),
      ),
      GoRoute(
        path: '/local-share',
        builder: (_, _) => const LocalShareScreen(),
      ),
      GoRoute(
        path: '/local-share/:deviceId',
        builder: (_, state) => LocalShareThreadScreen(
          deviceId: state.pathParameters['deviceId'] ?? '',
        ),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      // Where an incoming ACTION_SEND from another app lands.
      GoRoute(path: '/share', builder: (_, _) => const ShareTargetScreen()),
      GoRoute(
        path: '/settings/name',
        builder: (_, _) => const EditNameScreen(),
      ),
      GoRoute(
        path: '/settings/username',
        builder: (_, _) => const EditUsernameScreen(),
      ),
      // Your own code, not the scanner. The scanner is the icon in the chat
      // list header; this is the thing held up to it.
      GoRoute(path: '/settings/qr', builder: (_, _) => const MyQrScreen()),
      GoRoute(
        path: '/settings/discovery',
        builder: (_, _) => const DiscoveryScreen(),
      ),
      GoRoute(
        path: '/settings/privacy-mode',
        builder: (_, _) => const PrivacyModeScreen(),
      ),
      GoRoute(
        path: '/settings/privacy-mode/people',
        builder: (_, _) => const PrivacyPeopleScreen(),
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (_, _) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/media-quality',
        builder: (_, _) => const MediaQualityScreen(),
      ),
      // Signal's Data and storage, and the screens under it.
      GoRoute(
        path: '/settings/data-storage',
        builder: (_, _) => const DataStorageScreen(),
      ),
      GoRoute(
        path: '/settings/data-storage/chat-lock',
        builder: (_, _) => const ChatLockSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/chat-backup/recovery-codes',
        builder: (_, _) => const RecoveryCodesScreen(),
      ),
      GoRoute(
        path: '/settings/chat-backup/local',
        builder: (_, _) => const LocalBackupScreen(),
      ),
      GoRoute(
        path: '/settings/chat-backup',
        builder: (_, _) => const ChatBackupScreen(),
      ),
      GoRoute(
        path: '/settings/storage',
        builder: (_, _) => const StorageManagementScreen(),
      ),
      GoRoute(
        path: '/settings/storage/review',
        builder: (_, _) => const StorageReviewScreen(),
      ),
      // The default background for every chat.
      GoRoute(
        path: '/settings/app-icon',
        builder: (_, _) => const AppIconScreen(),
      ),
      GoRoute(
        path: '/settings/wallpaper',
        builder: (_, _) => const ChatWallpaperScreen(),
      ),
      // One chat's own background. Declared before '/messages/:id' would
      // swallow it, since ':id' matches a single segment only.
      // Signal's conversation settings. Declared before '/messages/:id' for
      // the same reason as the wallpaper route: ':id' matches one segment.
      // WhatsApp's Call info: one contact's calls on one day, from the call
      // log's stacked row. Outside the shell, like a chat.
      GoRoute(
        path: '/call-info/:id',
        builder: (_, state) => CallInfoScreen(
          conversationId: state.pathParameters['id']!,
          day: parseCallInfoDay(state.uri.queryParameters['day']),
        ),
      ),
      GoRoute(
        path: '/messages/:id/details',
        builder: (_, state) => ChatLockGate(
          conversationId: state.pathParameters['id']!,
          child: ConversationDetailsScreen(
            conversationId: state.pathParameters['id']!,
          ),
        ),
      ),
      // Group member permissions (server 0157). Declared before
      // '/messages/:id' for the same reason as the routes around them.
      GoRoute(
        path: '/messages/:id/permissions',
        builder: (_, state) =>
            GroupPermissionsScreen(conversationId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/messages/:id/members/:userId/permissions',
        builder: (_, state) => MemberPermissionsRoute(
          conversationId: state.pathParameters['id']!,
          userId: state.pathParameters['userId']!,
          member: state.extra is ChatMember ? state.extra as ChatMember : null,
        ),
      ),
      // Every member of a group, from "See all members" on details. The
      // roster details already holds rides in `extra` so it paints at once.
      GoRoute(
        path: '/messages/:id/members',
        builder: (_, state) => ChatLockGate(
          conversationId: state.pathParameters['id']!,
          child: GroupMembersScreen(
            conversationId: state.pathParameters['id']!,
            initialMembers: state.extra is List<ChatMember>
                ? state.extra as List<ChatMember>
                : const [],
          ),
        ),
      ),
      GoRoute(
        path: '/messages/:id/media',
        builder: (_, state) => ChatLockGate(
          conversationId: state.pathParameters['id']!,
          child: ConversationMediaScreen(
            conversationId: state.pathParameters['id']!,
          ),
        ),
      ),
      GoRoute(
        path: '/messages/:id/pins',
        builder: (_, state) => ChatLockGate(
          conversationId: state.pathParameters['id']!,
          child: PinnedMessagesScreen(
            conversationId: state.pathParameters['id']!,
          ),
        ),
      ),
      GoRoute(
        path: '/messages/:id/wallpaper',
        builder: (_, state) => ChatLockGate(
          conversationId: state.pathParameters['id']!,
          child: ChatWallpaperScreen(
            conversationId: state.pathParameters['id'],
          ),
        ),
      ),
      GoRoute(
        path: '/profile/devices',
        builder: (_, _) => const SessionsScreen(),
      ),
      GoRoute(
        path: '/messages/people',
        builder: (_, _) => const PeopleScreen(),
        routes: [
          GoRoute(path: 'find', builder: (_, _) => const FindPeopleScreen()),
          GoRoute(
            path: 'connections',
            builder: (_, _) => const ConnectionsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/messages/new',
        builder: (_, _) => const NewMessageScreen(),
      ),
      // Locked chats (device-local). Reached by a long press on the chat
      // list's title only. Declared before '/messages/:id' for the same
      // reason as the routes above.
      GoRoute(
        path: '/messages/locked',
        builder: (_, _) => const LockedChatsScreen(),
      ),
      GoRoute(
        path: '/messages/:id',
        builder: (_, state) => ChatLockGate(
          conversationId: state.pathParameters['id']!,
          relockOnLeave: true,
          child: ConversationScreen(
            conversationId: state.pathParameters['id']!,
            threadRootId: state.uri.queryParameters['thread'],
          ),
        ),
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
