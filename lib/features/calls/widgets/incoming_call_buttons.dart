import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'call_top_bar.dart' show callTextShadow;

/// Signal's `webrtc_hangup_background` / `webrtc_answer_background`.
const signalDeclineColor = Color(0xFFF07168);
const signalAnswerColor = Color(0xFF34C759);

/// One button of Signal's ringing screen with its label underneath
/// (`IncomingCallScreen.DeclineButtonAndLabel` / `AnswerCallButtonAndLabel`):
/// a filled circle, 6dp, then the word in `bodyMedium` with the text shadow.
///
/// A secondary action keeps the 78dp seat but draws a 56dp white circle in it
/// (Signal's `AnswerWithoutVideoButtonAndLabel`), so every label in a row
/// sits on the same line.
class IncomingCallButton extends StatelessWidget {
  const IncomingCallButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
    this.secondary = false,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  /// Fill of a primary button; ignored for [secondary].
  final Color? color;
  final bool secondary;

  /// A secondary button whose action already happened (Silence, once used).
  final bool selected;

  static const seat = 78.0;
  static const _secondaryDiameter = 56.0;
  static const _primaryIcon = 32.0;
  static const _secondaryIcon = 24.0;

  @override
  Widget build(BuildContext context) {
    final diameter = secondary ? _secondaryDiameter : seat;
    final fill = secondary
        ? (selected ? Colors.white : Colors.white.withValues(alpha: 0.24))
        : color ?? signalAnswerColor;
    final glyph = secondary && selected ? Colors.black : Colors.white;
    final text = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Colors.white,
      shadows: callTextShadow,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: seat,
          child: Center(
            child: Semantics(
              button: true,
              label: label,
              excludeSemantics: true,
              child: Material(
                color: fill,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onPressed == null
                      ? null
                      : () {
                          HapticFeedback.mediumImpact();
                          onPressed!();
                        },
                  child: SizedBox.square(
                    dimension: diameter,
                    child: Icon(
                      icon,
                      size: secondary ? _secondaryIcon : _primaryIcon,
                      color: glyph,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: text, textAlign: TextAlign.center),
      ],
    );
  }
}
