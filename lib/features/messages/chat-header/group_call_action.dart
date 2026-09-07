import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/router/router_path.dart';
import '../../calls/group/providers/group_call_provider.dart';
import '../data/models/chat_models.dart';
import 'call_action_pill.dart';

/// Channel header action: "Start call" when nobody is calling, "Join · N" when
/// a group call is live. Mirrors web `chat-header/group-call-action.tsx`,
/// including the 10s poll that keeps the count fresh without a socket event.
class GroupCallAction extends ConsumerStatefulWidget {
  const GroupCallAction({super.key, required this.conversation});

  final ChatConversation conversation;

  @override
  ConsumerState<GroupCallAction> createState() => _GroupCallActionState();
}

class _GroupCallActionState extends ConsumerState<GroupCallAction> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    unawaited(
      ref.read(groupCallProvider.notifier).refresh(widget.conversation.id),
    );
  }

  /// Back to the call screen the user minimised, without stacking a second
  /// copy of it — a double tap used to leave one `/group-call` route buried
  /// under the other, and leaving the call then popped only the top one.
  void _returnToCall(BuildContext context) {
    final router = GoRouter.of(context);
    if (currentRoutePath(router) == '/group-call') return;
    router.push('/group-call');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupCallProvider);
    final active = state.callFor(widget.conversation.id);
    final inThisCall =
        state.phase == GroupCallPhase.connected &&
        state.call?.conversationId == widget.conversation.id;
    final joiningThis =
        state.phase == GroupCallPhase.joining &&
        (state.call == null ||
            state.call?.conversationId == widget.conversation.id);
    final inLobbyForThis =
        state.phase == GroupCallPhase.lobby &&
        state.lobby?.conversationId == widget.conversation.id;
    // Already busy in some other call — joining a second one would drop it.
    final busyElsewhere =
        state.active && !inThisCall && !joiningThis && !inLobbyForThis;

    final label = inThisCall
        ? AppTranslations.translate(context, ref, 'chat_call_in')
        : active != null
        ? AppTranslations.translate(context, ref, 'chat_call_join')
        : AppTranslations.translate(context, ref, 'chat_call');

    return CallActionPill(
      icon: Icons.headset_mic_rounded,
      label: label,
      highlighted: inThisCall || active != null,
      busy: joiningThis,
      badgeCount: active?.participantCount ?? 0,
      // Already in this call means the user minimized it — take them back to
      // the call screen instead of a join that would no-op. Otherwise this
      // opens the lobby, not the call: the mic choice and the "who is already
      // in there" count both happen before anybody hears you.
      onTap: busyElsewhere || joiningThis
          ? null
          : inThisCall
          ? () => _returnToCall(context)
          // GroupCallSync owns the route: it pushes the lobby on the phase
          // edge, so pushing here too would open it twice.
          : () => ref
                .read(groupCallProvider.notifier)
                .openLobby(
                  widget.conversation.id,
                  conversationName: widget.conversation.name,
                ),
    );
  }
}
