import 'package:flutter/material.dart';

import 'call_glass_circle.dart';
import 'call_overlay_metrics.dart';
import 'call_top_bar.dart' show callTextShadow;
import '../../../shared/text/latin_tracking.dart';

/// Decline / Answer on the ringing screen — large paired seats, centred with
/// a comfortable gap rather than spread to the edges. Answer shows a camera
/// for a video call.
class IncomingCallPair extends StatelessWidget {
  const IncomingCallPair({
    super.key,
    required this.video,
    required this.declineLabel,
    required this.answerLabel,
    required this.showLabels,
    required this.onDecline,
    required this.onAccept,
  });

  final bool video;
  final String declineLabel;
  final String answerLabel;
  final bool showLabels;
  final VoidCallback onDecline;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final m = CallOverlayMetrics.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CallGlassCircle(
          icon: Icons.call_end_rounded,
          label: showLabels ? declineLabel : null,
          semanticLabel: declineLabel,
          diameter: m.incomingActionDiameter,
          iconSize: m.incomingActionIcon,
          labelFontSize: m.controlLabelFont,
          background: const Color(0xFFE2554A),
          foreground: Colors.white,
          glow: true,
          onPressed: onDecline,
        ),
        SizedBox(width: m.incomingActionGap),
        CallGlassCircle(
          icon: video ? Icons.videocam_rounded : Icons.call_rounded,
          label: showLabels ? answerLabel : null,
          semanticLabel: answerLabel,
          diameter: m.incomingActionDiameter,
          iconSize: m.incomingActionIcon,
          labelFontSize: m.controlLabelFont,
          background: const Color(0xFF2FBE61),
          foreground: Colors.white,
          glow: true,
          onPressed: onAccept,
        ),
      ],
    );
  }
}

/// "AbabilX voice call" at the top: which kind of call is ringing, before
/// the caller's name is even read.
class IncomingCallKindLabel extends StatelessWidget {
  const IncomingCallKindLabel({
    super.key,
    required this.video,
    required this.text,
  });

  final bool video;
  final String text;

  @override
  Widget build(BuildContext context) {
    final m = CallOverlayMetrics.of(context);
    final color = Colors.white.withValues(alpha: 0.78);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          // Not the Answer glyphs: those name the button, this names the call.
          video ? Icons.video_call_outlined : Icons.phone_in_talk_outlined,
          size: m.statusFont,
          color: color,
          shadows: callTextShadow,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: m.statusFont * 0.9,
            fontWeight: FontWeight.w500,
            letterSpacing: latinTracking(text, 0.2),
            shadows: callTextShadow,
          ),
        ),
      ],
    );
  }
}
