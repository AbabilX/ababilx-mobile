import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';
import '../../messages/data/models/chat_models.dart';
import '../quick-views/quick_view_summary.dart';
import 'catch_up_card.dart';
import 'catch_up_queue.dart';

/// Lets the bottom bar fly the same card the finger would swipe.
class CatchUpDeckController {
  void Function(CatchUpStep step)? _commit;

  /// Returns false when no deck is mounted (caller should step without fly).
  bool fly(CatchUpStep step) {
    final commit = _commit;
    if (commit == null) return false;
    commit(step);
    return true;
  }
}

/// Swipeable top card. Right → mark read, left → keep unread. Drag past
/// [_threshold] commits; otherwise it springs back. Stamp colours come
/// from the app theme.
class CatchUpDeck extends ConsumerStatefulWidget {
  const CatchUpDeck({
    super.key,
    required this.conversation,
    required this.onStep,
    this.behind = const [],
    this.controller,
  });

  final ChatConversation conversation;

  /// Next cards, nearest first, drawn stuck behind the front one.
  final List<ChatConversation> behind;
  final ValueChanged<CatchUpStep> onStep;
  final CatchUpDeckController? controller;

  @override
  ConsumerState<CatchUpDeck> createState() => _CatchUpDeckState();
}

class _CatchUpDeckState extends ConsumerState<CatchUpDeck>
    with SingleTickerProviderStateMixin {
  static const _threshold = 110.0;

  double _dx = 0;
  late final AnimationController _fly;
  Animation<Offset>? _flyAnim;
  CatchUpStep? _pending;

  @override
  void initState() {
    super.initState();
    widget.controller?._commit = commit;
    _fly =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 220),
        )..addStatusListener((status) {
          if (status != AnimationStatus.completed) return;
          final step = _pending;
          _pending = null;
          _dx = 0;
          _flyAnim = null;
          _fly.reset();
          if (step != null) widget.onStep(step);
        });
  }

  @override
  void didUpdateWidget(covariant CatchUpDeck old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?._commit = null;
      widget.controller?._commit = commit;
    }
    if (old.conversation.id != widget.conversation.id) {
      _dx = 0;
      _pending = null;
      _flyAnim = null;
      _fly.reset();
    }
  }

  @override
  void dispose() {
    widget.controller?._commit = null;
    _fly.dispose();
    super.dispose();
  }

  void _dragUpdate(DragUpdateDetails d) {
    if (_fly.isAnimating) return;
    setState(() => _dx += d.delta.dx);
  }

  void _dragEnd(DragEndDetails _) {
    if (_fly.isAnimating) return;
    if (_dx.abs() >= _threshold) {
      _commit(_dx > 0 ? CatchUpStep.markedRead : CatchUpStep.keptUnread);
    } else {
      setState(() => _dx = 0);
    }
  }

  void commit(CatchUpStep step) {
    if (_fly.isAnimating) return;
    _commit(step);
  }

  void _commit(CatchUpStep step) {
    final width = MediaQuery.sizeOf(context).width;
    final endX = step == CatchUpStep.markedRead ? width * 1.2 : -width * 1.2;
    _pending = step;
    _flyAnim = Tween<Offset>(
      begin: Offset(_dx, 0),
      end: Offset(endX, 0),
    ).animate(CurvedAnimation(parent: _fly, curve: Curves.easeIn));
    _fly.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final stuck = widget.behind.take(2).toList();
    final front = AnimatedBuilder(
      animation: _fly,
      builder: (context, child) {
        final o = _flyAnim?.value ?? Offset(_dx, 0);
        final progress = (o.dx / _threshold).clamp(-1.5, 1.5);
        return GestureDetector(
          onHorizontalDragUpdate: _dragUpdate,
          onHorizontalDragEnd: _dragEnd,
          child: Transform.translate(
            offset: o,
            child: Transform.rotate(
              angle: o.dx * 0.0012,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  child!,
                  if (progress > 0.15)
                    _Stamp(
                      fill: colors.primary,
                      ink: colors.onPrimary,
                      icon: HugeIcons.strokeRoundedTick02,
                      label: homeText(context, ref, 'home_catch_up_mark'),
                      opacity: progress.clamp(0, 1),
                    ),
                  if (progress < -0.15)
                    _Stamp(
                      fill: colors.secondary,
                      ink: colors.onSecondary,
                      icon: HugeIcons.strokeRoundedMail01,
                      label: homeText(context, ref, 'home_catch_up_keep'),
                      opacity: (-progress).clamp(0, 1),
                    ),
                ],
              ),
            ),
          ),
        );
      },
      child: CatchUpCard(conversation: widget.conversation),
    );
    if (stuck.isEmpty) return front;
    // Tops of the next cards stick out above the one being swiped.
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = stuck.length - 1; i >= 0; i--)
          Positioned(
            top: 0,
            left: 10.0 * (i + 1),
            right: 10.0 * (i + 1),
            bottom: 16.0 * (i + 1),
            child: IgnorePointer(child: CatchUpCard(conversation: stuck[i])),
          ),
        Positioned(
          top: 14.0 * stuck.length,
          left: 0,
          right: 0,
          bottom: 0,
          child: front,
        ),
      ],
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({
    required this.fill,
    required this.ink,
    required this.icon,
    required this.label,
    required this.opacity,
  });

  final Color fill;
  final Color ink;
  final List<List<dynamic>> icon;
  final String label;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ink, width: 3),
                  ),
                  child: ChatIcon(icon, color: ink, size: 32),
                ),
                const SizedBox(height: 16),
                Text(
                  label,
                  style: text.titleLarge?.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
