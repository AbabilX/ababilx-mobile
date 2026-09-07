import 'package:flutter/material.dart';

import '../providers/group_call_state.dart';
import '../signals/call_signals.dart';

/// Reactions drift up from the bottom of the stage and fade. Purely decorative
/// and hit-test transparent — nothing here can swallow a press meant for the
/// control bar underneath.
class ReactionBurst extends StatelessWidget {
  const ReactionBurst({super.key, required this.reactions});

  final List<GroupCallReaction> reactions;

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: Stack(
        children: [
          for (var index = 0; index < reactions.length; index++)
            Positioned(
              bottom: 0,
              left: 24.0 + (index * 47) % 180,
              child: _FloatingEmoji(
                key: ValueKey(reactions[index].id),
                emoji: reactions[index].emoji,
              ),
            ),
        ],
      ),
    );
  }
}

class _FloatingEmoji extends StatefulWidget {
  const _FloatingEmoji({super.key, required this.emoji});
  final String emoji;

  @override
  State<_FloatingEmoji> createState() => _FloatingEmojiState();
}

class _FloatingEmojiState extends State<_FloatingEmoji>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: reactionTtl,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (_, _) {
      final t = _controller.value;
      return Transform.translate(
        offset: Offset(0, -160 * t),
        child: Opacity(
          opacity: t < 0.12 ? t / 0.12 : (1 - (t - 0.12) / 0.88).clamp(0, 1),
          child: Text(widget.emoji, style: const TextStyle(fontSize: 30)),
        ),
      );
    },
  );
}
