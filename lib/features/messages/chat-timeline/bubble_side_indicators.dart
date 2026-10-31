import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat-select/message_selection.dart';
import '../chat_icon.dart';
import '../data/models/chat_models.dart';
import 'message_swipe_reply.dart';
import 'quote_replies_sheet.dart';

/// What a timeline tells its rows about the side indicators. A row drawn
/// outside one — the copy the long-press menu lifts, the replies sheet — has
/// no scope and so draws none, which is the reference app's rule for both.
class BubbleIndicatorScope extends InheritedWidget {
  const BubbleIndicatorScope({
    super.key,
    required this.quotedIds,
    required this.threadRootId,
    required super.child,
  });

  final Set<String> quotedIds;
  final String? threadRootId;

  static BubbleIndicatorScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BubbleIndicatorScope>();

  @override
  bool updateShouldNotify(BubbleIndicatorScope old) =>
      old.quotedIds.length != quotedIds.length ||
      !old.quotedIds.containsAll(quotedIds);
}

/// The reference app's `quoted_indicator`: a 32dp circle beside the bubble, on
/// the side facing the middle of the screen, centred on the bubble. One for a
/// message that has been quoted (opens its replies), a different glyph for a
/// message that carries a thread (opens the thread).
class BubbleSideIndicators extends ConsumerWidget {
  const BubbleSideIndicators({
    super.key,
    required this.message,
    required this.isOwn,
    required this.child,
    this.onOpenThread,
  });

  final ChatMessage message;
  final bool isOwn;
  final Widget child;
  final VoidCallback? onOpenThread;

  static const size = 32.0;
  static const gap = 10.0;
  static const repliesKey = Key('bubble-replies-indicator');
  static const threadKey = Key('bubble-thread-indicator');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = BubbleIndicatorScope.maybeOf(context);
    if (scope == null || message.isDeleted) return child;
    final quoted = scope.quotedIds.contains(message.id);
    final threaded = onOpenThread != null && message.threadCount > 0;
    if (!quoted && !threaded) return child;
    // The reference app hides it while messages are being picked out.
    final selecting = ref.watch(
      messageSelectionProvider.select(
        (s) => s.isActiveIn(message.conversationId),
      ),
    );
    if (selecting) return child;

    final marks = [
      if (threaded)
        _Indicator(
          key: threadKey,
          icon: HugeIcons.strokeRoundedThread,
          onTap: onOpenThread!,
        ),
      if (quoted)
        _Indicator(
          key: repliesKey,
          icon: HugeIcons.strokeRoundedMessageMultiple01,
          onTap: () => showQuoteRepliesSheet(
            context,
            message,
            threadRootId: scope.threadRootId,
          ),
        ),
    ];
    final strip = _SwipeFade(
      child: Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: marks),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isOwn) ...[strip, const SizedBox(width: gap)],
        Flexible(child: child),
        if (!isOwn) ...[const SizedBox(width: gap), strip],
      ],
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({super.key, required this.icon, required this.onTap});

  final List<List<dynamic>> icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox.square(
          dimension: BubbleSideIndicators.size,
          child: Center(
            child: ChatIcon(
              icon,
              size: 20,
              strokeWidth: 1.5,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// The reference app's `QUOTED_ALPHA_INTERPOLATOR`: gone by a third of the way
/// to the swipe trigger, so the reply arrow never shares the row with it.
class _SwipeFade extends StatelessWidget {
  const _SwipeFade({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final progress = SwipeReplyProgress.maybeOf(context);
    if (progress == null) return child;
    return ValueListenableBuilder<double>(
      valueListenable: progress,
      child: child,
      builder: (_, value, child) =>
          Opacity(opacity: (1 - value * 3).clamp(0.0, 1.0), child: child),
    );
  }
}
