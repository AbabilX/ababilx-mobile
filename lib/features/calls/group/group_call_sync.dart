import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_provider.dart';
import '../../messages/providers/team_gate_provider.dart';
import 'providers/group_call_provider.dart';

/// App-level lifecycle for channel group calls: boots the socket listener once
/// the user has a team, and drives navigation in and out of `/group-call`.
///
/// The 1:1 DM equivalent is [CallStoreSync]; the two stay separate because the
/// DM path also has to coordinate CallKit, which group calls never use.
class GroupCallSync extends ConsumerStatefulWidget {
  const GroupCallSync({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<GroupCallSync> createState() => _GroupCallSyncState();
}

class _GroupCallSyncState extends ConsumerState<GroupCallSync> {
  static const _route = '/group-call';
  bool _booted = false;

  String get _currentPath =>
      widget.router.routerDelegate.currentConfiguration.uri.path;

  @override
  Widget build(BuildContext context) {
    final loggedIn = ref.watch(authProvider).valueOrNull ?? false;
    final hasTeam = ref.watch(hasTeamProvider);

    if (loggedIn && hasTeam && !_booted) {
      _booted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(ref.read(groupCallProvider.notifier).bootstrap());
      });
    }
    if ((!loggedIn || !hasTeam) && _booted) {
      _booted = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(ref.read(groupCallProvider.notifier).shutdown());
      });
    }

    ref.listen(groupCallProvider, (previous, next) {
      if (next.active) {
        // Only on the edge into a call. The state churns constantly while
        // connected (speaking, mutes, joins) and re-pushing on every tick
        // would drag a user who minimized straight back into the call screen.
        if (previous?.active != true) _openCallScreen();
        return;
      }
      // Left, failed, or the call ended for everyone — get off the call screen.
      // The conversation id has to come from the previous state: teardown
      // clears `call` before this listener runs.
      if (previous?.active == true) {
        _leaveCallScreen(previous?.call?.conversationId);
      }
    });

    return widget.child;
  }

  void _openCallScreen() {
    if (_currentPath == _route) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _currentPath == _route) return;
      if (!ref.read(groupCallProvider).active) return;
      widget.router.push(_route);
    });
  }

  void _leaveCallScreen(String? conversationId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _currentPath != _route) return;
      if (ref.read(groupCallProvider).active) return;
      if (widget.router.canPop()) {
        widget.router.pop();
      } else if (conversationId != null && conversationId.isNotEmpty) {
        widget.router.go('/messages/$conversationId');
      } else {
        widget.router.go('/messages');
      }
    });
  }
}
