import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/localization/app_translations.dart';
import '../widgets/call_glass_circle.dart';
import '../widgets/call_overlay_metrics.dart';
import '../widgets/call_peer_identity.dart';
import '../widgets/call_wallpaper.dart';

/// Ringing incoming call — same wallpaper + identity language as outgoing,
/// with Answer / Decline as the only actions (no mid-call toggles yet).
class IncomingCallView extends StatelessWidget {
  const IncomingCallView({
    super.key,
    required this.peerName,
    required this.peerAvatar,
    required this.onDecline,
    required this.onAccept,
    this.lang = 'en',
  });

  final String peerName;
  final String? peerAvatar;
  final VoidCallback onDecline;
  final VoidCallback onAccept;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final m = CallOverlayMetrics.of(context);
    final padding = MediaQuery.paddingOf(context);
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    String tr(String key) => AppTranslations.of(lang, key);
    final identityTop = CallOverlayMetrics.clampTop(
      m.avatarTop,
      min: padding.top + 48,
      max: m.size.height * 0.42,
    );
    final decline = tr('call_control_decline');
    final answer = tr('call_control_answer');

    return Stack(
      fit: StackFit.expand,
      children: [
        const CallWallpaper(),
        Positioned(
          top: identityTop,
          left: math.max(padding.left, 12),
          right: math.max(padding.right, 12),
          child: CallPeerIdentity(
            name: peerName,
            avatarUrl: peerAvatar,
            status: tr('call_status_incoming'),
            showWave: !landscape,
          ),
        ),
        Positioned(
          left: math.max(padding.left, m.sideMargin),
          right: math.max(padding.right, m.sideMargin),
          bottom: m.incomingActionsBottom(padding.bottom),
          child: Row(
            // Centered pair with comfortable gap — not edge-to-edge.
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CallGlassCircle(
                icon: Icons.call_end_rounded,
                label: landscape ? null : decline,
                semanticLabel: decline,
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
                icon: Icons.call_rounded,
                label: landscape ? null : answer,
                semanticLabel: answer,
                diameter: m.incomingActionDiameter,
                iconSize: m.incomingActionIcon,
                labelFontSize: m.controlLabelFont,
                background: const Color(0xFF2FBE61),
                foreground: Colors.white,
                glow: true,
                onPressed: onAccept,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
