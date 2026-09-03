import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'signal_bubble_metrics.dart';

/// Signal's swipe-to-reply: drag a message to the right, an arrow fades in and
/// grows, and letting go past the trigger point starts a reply.
///
/// Numbers are Signal's own (`ConversationSwipeAnimationHelper`): the gesture
/// passes at 64, cannot travel past 96, the arrow scales 1.0 → 1.2 on the way
/// and kicks to 1.8 for 200ms the moment it passes, with a 10ms haptic.
class MessageSwipeReply extends StatefulWidget {
  const MessageSwipeReply({
    super.key,
    required this.child,
    required this.onReply,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback onReply;
  final bool enabled;

  @override
  State<MessageSwipeReply> createState() => _MessageSwipeReplyState();
}

class _MessageSwipeReplyState extends State<MessageSwipeReply>
    with TickerProviderStateMixin {
  static const _trigger = SignalBubbleMetrics.swipeTriggerDx;
  static const _max = SignalBubbleMetrics.swipeMaxDx;

  // Built in initState, not `late final`: a row that is never swiped would
  // otherwise run the initialiser from dispose(), and creating a Ticker on a
  // deactivated element throws.
  late final AnimationController _release;
  late final AnimationController _overshoot;

  double _dx = 0;
  double _releaseFrom = 0;
  bool _passed = false;

  @override
  void initState() {
    super.initState();
    _release = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(_onRelease);
    _overshoot = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  void _onRelease() {
    if (!mounted) return;
    setState(() => _dx = _releaseFrom * (1 - _release.value));
  }

  @override
  void dispose() {
    _release.dispose();
    _overshoot.dispose();
    super.dispose();
  }

  void _onUpdate(DragUpdateDetails details) {
    // Past the trigger the bubble keeps moving, but grudgingly — that drag is
    // what tells your thumb the gesture has already taken.
    final raw = _dx + details.delta.dx * (_dx >= _trigger ? 0.35 : 1);
    final next = raw.clamp(0.0, _max);
    if (next >= _trigger && !_passed) {
      _passed = true;
      HapticFeedback.selectionClick();
      _overshoot.forward(from: 0);
    } else if (next < _trigger && _passed) {
      _passed = false;
    }
    setState(() => _dx = next);
  }

  void _onEnd() {
    final fire = _passed;
    _passed = false;
    _releaseFrom = _dx;
    _release.forward(from: 0);
    if (fire) widget.onReply();
  }

  /// 1.0 up to the trigger, then Signal's kick out to 1.8 and back.
  double get _iconScale {
    final base = (_dx / _trigger).clamp(0.0, 1.0) * 0.2 + 1.0;
    if (!_overshoot.isAnimating) return base;
    final t = _overshoot.value;
    final kick = t < 0.5 ? t * 2 : (1 - t) * 2;
    return base + kick * 0.6;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final colors = Theme.of(context).colorScheme;
    final progress = (_dx / _trigger).clamp(0.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: (_) => _onEnd(),
      onHorizontalDragCancel: _onEnd,
      child: Stack(
        children: [
          if (_dx > 0)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: AnimatedBuilder(
                    animation: _overshoot,
                    builder: (_, _) => Opacity(
                      opacity: progress,
                      child: Transform.scale(
                        scale: _iconScale,
                        child: Container(
                          width: SignalBubbleMetrics.replyIconSize,
                          height: SignalBubbleMetrics.replyIconSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.surfaceContainerHighest,
                          ),
                          child: Icon(
                            Icons.reply_rounded,
                            size: 20,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Transform.translate(offset: Offset(_dx, 0), child: widget.child),
        ],
      ),
    );
  }
}
