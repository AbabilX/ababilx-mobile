import 'package:flutter/material.dart';

import 'call_top_bar.dart' show callTextShadow;

/// "End-to-end encrypted" with a lock, over the 1:1 call's controls.
class CallEncryptedLabel extends StatelessWidget {
  const CallEncryptedLabel({
    super.key,
    required this.text,
    required this.fontSize,
  });

  final String text;
  final double fontSize;

  /// Height the label takes at [fontSize], for whoever budgets the deck.
  static double heightFor(double scaledFontSize) => scaledFontSize * 1.35;

  @override
  Widget build(BuildContext context) {
    final color = Colors.white.withValues(alpha: 0.78);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.lock_rounded,
          size: fontSize,
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
              fontSize: fontSize,
              height: 1.35,
              fontWeight: FontWeight.w500,
              shadows: callTextShadow,
            ),
          ),
        ),
      ],
    );
  }
}
