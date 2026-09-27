import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../chat-lock/providers/chat_locks_provider.dart';
import '../../messages/chat-recipient-picker/chat_recipient_eligible.dart';
import '../../messages/providers/chat_provider.dart';
import 'direct_share_channel.dart';
import 'direct_share_targets.dart';

/// Keeps the system share sheet's Direct Share row in step with the chat
/// list: the most recent chats that can take a share, locked chats never.
///
/// Publishes only when the row would actually change, and a moment after the
/// last change — a burst of messages must not become a burst of shortcut
/// writes, which Android rate-limits. Signed out, the row is cleared.
class DirectShareSync extends ConsumerStatefulWidget {
  const DirectShareSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DirectShareSync> createState() => _DirectShareSyncState();
}

class _DirectShareSyncState extends ConsumerState<DirectShareSync> {
  static const _channel = DirectShareChannel();
  Timer? _debounce;

  /// What was last sent to Kotlin; null until the first send of this launch,
  /// so every launch publishes once.
  String? _sent;

  @override
  void initState() {
    super.initState();
    ref.listenManual(authProvider, (_, _) => _schedule());
    ref.listenManual(chatLocksProvider, (_, _) => _schedule());
    ref.listenManual(
      chatProvider,
      (_, _) => _schedule(),
      fireImmediately: true,
    );
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), _sync);
  }

  void _sync() {
    if (!mounted) return;
    final signedIn = ref.read(authProvider).valueOrNull ?? false;
    if (!signedIn) {
      if (_sent == '') return;
      _sent = '';
      unawaited(_channel.clear());
      return;
    }
    final chat = ref.read(chatProvider);
    final shareable = shareableConversations(
      dms: chat.dms,
      channels: chat.channels,
      locks: ref.read(chatLocksProvider),
    );
    // An empty list is a chat list that has not loaded yet, not a user with
    // no chats; publishing it would wipe the row on every cold start.
    if (shareable.isEmpty) return;
    final targets = directShareTargets(shareable, chat.currentUserId);
    final signature = jsonEncode(targets);
    if (signature == _sent) return;
    _sent = signature;
    unawaited(_channel.publish(targets));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
