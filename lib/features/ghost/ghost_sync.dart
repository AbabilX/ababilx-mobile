import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/router_path.dart';
import '../auth/providers/auth_provider.dart';
import 'native/ghost_blobs.dart';
import 'native/ghost_secure_window.dart';
import 'providers/ghost_provider.dart';
import 'providers/ghost_state.dart';
import 'providers/ghost_temp_files.dart';

/// App-level owner of Ghost Chat: boots the provider once signed in, owns
/// every Ghost Chat route change, forwards app lifecycle, and holds the secure
/// window flag. Screens never navigate themselves — two places pushing races,
/// and the invite → chat handoff must be a replacement, or leaving the chat
/// would land back on a dead invite. Same arrangement as `GroupCallSync`.
class GhostSync extends ConsumerStatefulWidget {
  const GhostSync({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  static const chatRoute = '/ghost';
  static const inviteRoute = '/ghost/invite';

  @override
  ConsumerState<GhostSync> createState() => _GhostSyncState();
}

class _GhostSyncState extends ConsumerState<GhostSync>
    with WidgetsBindingObserver {
  bool _booted = false;

  String get _path => currentRoutePath(widget.router);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // A process killed mid-session leaves any opened document behind. Blobs
    // die with the process, but a restarted process may still hold them if
    // only the Flutter engine was recreated.
    unawaited(GhostBlobs.clear());
    unawaited(GhostTempFiles.purge());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_booted) ref.read(ghostProvider.notifier).onAppLifecycle(state);
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = ref.watch(authProvider).valueOrNull == true;
    if (loggedIn && !_booted) {
      _booted = true;
      // Reading it subscribes it to the socket, so invites can arrive.
      ref.read(ghostProvider);
    }
    if (!loggedIn && _booted && ref.read(ghostProvider).inSession) {
      // Signing out mid-session leaves, which burns, like any other exit.
      _after(() {
        ref.read(ghostProvider.notifier).leave();
        return null;
      });
    }

    ref.listen(ghostProvider, (previous, next) {
      final was = previous?.phase ?? GhostPhase.idle;
      final now = next.phase;
      if (was == now) return;
      unawaited(GhostSecureWindow.set(now != GhostPhase.idle));
      switch (now) {
        case GhostPhase.inviting:
          _after(
            () => _path == GhostSync.chatRoute
                ? null
                : widget.router.push(GhostSync.chatRoute),
          );
        case GhostPhase.invited:
          _after(
            () => _path == GhostSync.inviteRoute
                ? null
                : widget.router.push(GhostSync.inviteRoute),
          );
        case GhostPhase.connecting when was == GhostPhase.accepting:
          _after(
            () => _path == GhostSync.inviteRoute
                ? widget.router.pushReplacement(GhostSync.chatRoute)
                : widget.router.push(GhostSync.chatRoute),
          );
        case GhostPhase.ended when _path == GhostSync.inviteRoute:
          // Join failed: show why on the chat screen, not on a dead invite.
          _after(() => widget.router.pushReplacement(GhostSync.chatRoute));
        case GhostPhase.idle:
          _after(_leaveGhostRoutes);
        default:
      }
    });
    return widget.child;
  }

  void _after(Object? Function() action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) action();
    });
  }

  void _leaveGhostRoutes() {
    if (ref.read(ghostProvider).phase != GhostPhase.idle) return;
    final path = _path;
    if (path != GhostSync.chatRoute && path != GhostSync.inviteRoute) return;
    if (widget.router.canPop()) {
      widget.router.pop();
    } else {
      widget.router.go('/messages');
    }
  }
}
