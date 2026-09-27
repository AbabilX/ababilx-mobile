import 'package:flutter/material.dart';

import 'call_glass_circle.dart';
import 'call_overlay_metrics.dart';

/// The small row above Decline / Answer on the ringing screen: Message
/// (decline with a text) and Silence (quiet the tone, keep ringing). Smaller
/// glass seats than the pair, so the eye still lands on answer or refuse.
class IncomingCallSecondary extends StatelessWidget {
  const IncomingCallSecondary({
    super.key,
    required this.messageLabel,
    required this.silenceLabel,
    required this.silenced,
    required this.showLabels,
    this.onMessage,
    this.onSilence,
  });

  final String messageLabel;
  final String silenceLabel;
  final bool silenced;
  final bool showLabels;

  /// Null hides Message — no conversation to write into.
  final VoidCallback? onMessage;
  final VoidCallback? onSilence;

  @override
  Widget build(BuildContext context) {
    final m = CallOverlayMetrics.of(context);
    Widget seat({
      required IconData icon,
      required String label,
      required VoidCallback? onPressed,
      bool selected = false,
    }) => CallGlassCircle(
      icon: icon,
      label: showLabels ? label : null,
      semanticLabel: label,
      diameter: m.hangupDiameter,
      iconSize: m.hangupIcon * 0.9,
      labelFontSize: m.hangupLabelFont,
      selected: selected,
      onPressed: onPressed,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onMessage != null) ...[
          seat(
            icon: Icons.chat_bubble_outline_rounded,
            label: messageLabel,
            onPressed: onMessage,
          ),
          // Centres line up over Decline and Answer below.
          SizedBox(
            width:
                m.incomingActionDiameter +
                m.incomingActionGap -
                m.hangupDiameter,
          ),
        ],
        seat(
          icon: silenced
              ? Icons.notifications_off_rounded
              : Icons.notifications_off_outlined,
          label: silenceLabel,
          selected: silenced,
          // Already quiet: nothing left for the button to do.
          onPressed: silenced ? null : onSilence,
        ),
      ],
    );
  }
}
