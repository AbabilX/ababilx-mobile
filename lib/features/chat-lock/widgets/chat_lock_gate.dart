import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/chat_lock_session.dart';
import '../providers/chat_locks_provider.dart';
import '../screens/chat_lock_screen.dart';

/// Wraps every screen of one conversation (the chat, its details, media,
/// pins, wallpaper). A locked chat that is not open this session gets the
/// lock screen INSTEAD of [child] — the chat is never built, so nothing is
/// fetched, marked read or drawn behind the lock.
///
/// [relockOnLeave] is set on the chat itself: closing it locks it again.
/// Its sub-screens sit on top of it, so they do not.
class ChatLockGate extends ConsumerStatefulWidget {
  const ChatLockGate({
    super.key,
    required this.conversationId,
    required this.child,
    this.relockOnLeave = false,
  });

  final String conversationId;
  final Widget child;
  final bool relockOnLeave;

  @override
  ConsumerState<ChatLockGate> createState() => _ChatLockGateState();
}

class _ChatLockGateState extends ConsumerState<ChatLockGate> {
  // Read in initState: dispose, where it is used, may not touch ref.
  late final ChatLockSession _session;

  @override
  void initState() {
    super.initState();
    _session = ref.read(chatLockSessionProvider.notifier);
  }

  @override
  void dispose() {
    if (widget.relockOnLeave) {
      final id = widget.conversationId;
      // Not synchronously: providers may not change while the tree unmounts.
      scheduleMicrotask(() => _session.relock(id));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.conversationId;
    if (!ref.watch(isChatLockedProvider(id))) return widget.child;
    final open = ref.watch(chatLockSessionProvider.select((s) => s.isOpen(id)));
    return open ? widget.child : ChatLockScreen(conversationId: id);
  }
}
