import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';
import '../../messages/providers/chat_provider.dart';
import '../data/home_chats.dart';
import '../quick-views/quick_view_summary.dart';
import 'catch_up_bar.dart';
import 'catch_up_deck.dart';
import 'catch_up_queue.dart';

/// Full-screen Catch up: swipe / tap through unread chats one card at a
/// time. Colours follow the app theme; icons are HugeIcons via [ChatIcon].
class CatchUpScreen extends ConsumerStatefulWidget {
  const CatchUpScreen({super.key});

  @override
  ConsumerState<CatchUpScreen> createState() => _CatchUpScreenState();
}

class _CatchUpScreenState extends ConsumerState<CatchUpScreen> {
  CatchUpQueue? _queue;
  Map<String, int> _unreadAtStart = const {};
  final _deck = CatchUpDeckController();
  var _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_queue != null) return;
    final unread = ref.read(homeUnreadProvider);
    _queue = CatchUpQueue([for (final c in unread) c.id]);
    _unreadAtStart = {for (final c in unread) c.id: c.unreadCount};
  }

  Future<void> _step(CatchUpStep step) async {
    final queue = _queue;
    if (queue == null || queue.isEmpty || _busy) return;
    final id = queue.current!;
    setState(() {
      _busy = true;
      queue.advance(step);
    });
    if (step == CatchUpStep.markedRead) {
      await ref.read(chatProvider.notifier).markConversationRead(id);
    }
    if (!mounted) return;
    setState(() => _busy = false);
  }

  void _undo() {
    final queue = _queue;
    if (queue == null || !queue.canUndo || _busy) return;
    // Undo only restores the deck. A mark-read already reached the server —
    // bringing the card back lets the user open it or Keep Unread again;
    // we do not invent an "unread" API.
    setState(() => queue.revert());
  }

  void _fly(CatchUpStep step) {
    if (_queue?.current == null || !_deck.fly(step)) {
      _step(step);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final queue = _queue!;
    final chats = ref.watch(homeConversationsProvider);
    final currentId = queue.current;
    var current =
        currentId == null ? null : homeConversationById(chats, currentId);
    // Chat left / locked / gone mid-session — drop it, no undo entry.
    if (currentId != null && current == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _queue?.current != currentId) return;
        setState(() => _queue!.remaining.removeAt(0));
      });
    }
    if (current != null) {
      final n = _unreadAtStart[current.id];
      if (n != null && n != current.unreadCount) {
        current = current.copyWith(unreadCount: n);
      }
    }

    return Scaffold(
      // Below the card's surfaceContainerHigh so the deck reads as a panel.
      backgroundColor: colors.surfaceContainerLowest,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              left: queue.left,
              canUndo: queue.canUndo && !_busy,
              onClose: () => context.pop(),
              onUndo: _undo,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: current == null
                    ? const _Done()
                    : CatchUpDeck(
                        conversation: current,
                        behind: [
                          for (final id in queue.behind())
                            ?homeConversationById(chats, id),
                        ],
                        controller: _deck,
                        onStep: _step,
                      ),
              ),
            ),
            if (current != null)
              CatchUpBar(onStep: _fly, enabled: !_busy)
            else
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: FilledButton.icon(
                    onPressed: () => context.pop(),
                    icon: ChatIcon(
                      HugeIcons.strokeRoundedTick02,
                      size: 20,
                      color: colors.onPrimary,
                    ),
                    label: Text(
                      homeText(context, ref, 'home_catch_up_done_cta'),
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.left,
    required this.canUndo,
    required this.onClose,
    required this.onUndo,
  });

  final int left;
  final bool canUndo;
  final VoidCallback onClose;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: ChatIcon(
              HugeIcons.strokeRoundedCancel01,
              color: colors.onSurface,
              size: 24,
            ),
          ),
          Expanded(
            child: Text(
              left == 0
                  ? homeText(context, ref, 'home_catch_up_done')
                  : homeText(context, ref, 'home_catch_up_left', left),
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: canUndo ? onUndo : null,
            icon: ChatIcon(
              HugeIcons.strokeRoundedUndo,
              size: 18,
              color: canUndo
                  ? colors.primary
                  : colors.onSurface.withValues(alpha: 0.38),
            ),
            label: Text(homeText(context, ref, 'home_catch_up_undo')),
            style: TextButton.styleFrom(
              foregroundColor: colors.primary,
              disabledForegroundColor: colors.onSurface.withValues(alpha: 0.38),
            ),
          ),
        ],
      ),
    );
  }
}

class _Done extends ConsumerWidget {
  const _Done();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: colors.primaryContainer,
            child: ChatIcon(
              HugeIcons.strokeRoundedTick02,
              color: colors.onPrimaryContainer,
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            homeText(context, ref, 'home_catch_up_done'),
            style: text.headlineSmall?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            homeText(context, ref, 'home_focus_clear_sub'),
            style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
