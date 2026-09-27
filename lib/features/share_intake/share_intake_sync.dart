import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/providers/auth_provider.dart';
import '../messages/message_e2ee/message_entry_ready.dart';
import 'data/shared_payload.dart';
import 'providers/share_intake_provider.dart';

/// App-wide intake for shares coming from other apps' share sheets.
///
/// Two jobs, and they are separate on purpose:
///
///  1. Start listening as soon as the app is up, signed in or not — a share
///     that cold-starts the app arrives before anything else exists, and
///     dropping it would look to the user like the app simply ignored them.
///  2. Route to the picker only once there is somewhere to route *to*: signed
///     in, with the router mounted. A share received while signed out sits in
///     the provider and opens the moment the user finishes logging in.
class ShareIntakeSync extends ConsumerStatefulWidget {
  const ShareIntakeSync({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<ShareIntakeSync> createState() => _ShareIntakeSyncState();
}

class _ShareIntakeSyncState extends ConsumerState<ShareIntakeSync> {
  bool _listening = false;
  bool _routing = false;

  /// The exact payload the picker was already opened for. Identity, not
  /// equality: sharing the same two photos twice is a second share and must
  /// open the picker again.
  SharedPayload? _routedFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _listening) return;
      _listening = true;
      unawaited(ref.read(shareIntakeProvider.notifier).start());
    });
  }

  void _openPickerIfPending() {
    if (_routing) return;
    final pending = ref.read(shareIntakeProvider);
    if (pending == null) {
      _routedFor = null;
      return;
    }
    if (identical(_routedFor, pending)) return;
    if (!(ref.read(authProvider).valueOrNull ?? false)) return;
    // The router redirects any push away from `/share` to `/message-recovery`
    // while this is false, then on to `/messages` once it flips — dropping the
    // share with no retry, since `_routedFor` below would already be set.
    if (!ref.read(messageEntryReadyProvider)) return;

    _routing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routing = false;
      if (!mounted) return;
      final payload = ref.read(shareIntakeProvider);
      if (payload == null || identical(_routedFor, payload)) return;
      _routedFor = payload;
      // Re-sharing while the picker is already up replaces the payload; it
      // must not stack a second copy of the screen.
      if (widget.router.state.matchedLocation == _sharePath) return;
      widget.router.push(_sharePath);
    });
  }

  /// A Direct Share shortcut tapped from the launcher's long press: open that
  /// chat, over the chat list so back lands somewhere.
  void _openShortcutIfPending() {
    final id = ref.read(shortcutOpenProvider);
    if (id == null) return;
    if (!(ref.read(authProvider).valueOrNull ?? false)) return;
    if (!ref.read(messageEntryReadyProvider)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ref.read(shortcutOpenProvider) != id) return;
      ref.read(shortcutOpenProvider.notifier).state = null;
      widget.router.go('/messages');
      // Same beat as a notification tap: the list settles, then the chat.
      Future<void>.delayed(
        const Duration(milliseconds: 50),
        () => widget.router.push('/messages/$id'),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // All three are watched: a share can land before sign-in, a sign-in can
    // land after the share, and the recovery gate can still be mid-flight
    // when both of those are already satisfied.
    ref.watch(shareIntakeProvider);
    ref.watch(authProvider);
    ref.watch(messageEntryReadyProvider);
    ref.watch(shortcutOpenProvider);
    _openPickerIfPending();
    _openShortcutIfPending();
    return widget.child;
  }
}

const _sharePath = '/share';
