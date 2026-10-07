import 'dart:async';

import 'package:flutter/material.dart';

import 'call_top_bar.dart' show callTextShadow;

/// The lock line over the 1:1 call's controls. With more than one of
/// [lines] it turns them over in place: the old one slides up and fades as
/// the next rises from under it.
class CallEncryptedLabel extends StatefulWidget {
  const CallEncryptedLabel({
    super.key,
    required this.lines,
    required this.fontSize,
  });

  final List<String> lines;
  final double fontSize;

  /// Height the label takes at [scaledFontSize], for whoever budgets the deck.
  static double heightFor(double scaledFontSize) => scaledFontSize * 1.35;

  static const hold = Duration(seconds: 4);
  static const turn = Duration(milliseconds: 420);

  @override
  State<CallEncryptedLabel> createState() => _CallEncryptedLabelState();
}

class _CallEncryptedLabelState extends State<CallEncryptedLabel> {
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    if (widget.lines.length < 2) return;
    _timer = Timer.periodic(CallEncryptedLabel.hold, (_) {
      if (mounted) setState(() => _index++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Colors.white.withValues(alpha: 0.78);
    final text = widget.lines[_index % widget.lines.length];
    final still = MediaQuery.disableAnimationsOf(context);
    return ClipRect(
      child: AnimatedSwitcher(
        duration: still ? Duration.zero : CallEncryptedLabel.turn,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          // The incoming line rises from below; the outgoing one runs the
          // same animation in reverse, so it is mirrored to leave upward.
          final incoming = child.key == ValueKey(text);
          final offset = Tween<Offset>(
            begin: Offset(0, incoming ? 0.9 : -0.9),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: offset, child: child),
          );
        },
        child: Row(
          key: ValueKey(text),
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_rounded,
              size: widget.fontSize,
              color: color,
              shadows: callTextShadow,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: widget.fontSize,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                  shadows: callTextShadow,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
