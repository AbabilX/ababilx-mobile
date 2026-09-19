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
    final bottomInset = padding.bottom;
    String tr(String key) => AppTranslations.of(lang, key);
    final identityTop = CallOverlayMetrics.clampTop(
      m.avatarTop,
      min: padding.top + 36,
      max: m.size.height * 0.42,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        const CallWallpaper(),
        Positioned(
          top: identityTop,
          left: 0,
          right: 0,
          child: CallPeerIdentity(
            name: peerName,
            avatarUrl: peerAvatar,
            status: tr('call_status_incoming'),
            showWave: true,
          ),
        ),
        Positioned(
          left: m.sideMargin * 1.4,
          right: m.sideMargin * 1.4,
          bottom: m.hangupBottomClearance(bottomInset),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CallGlassCircle(
                icon: Icons.call_end_rounded,
                label: tr('call_control_decline'),
                diameter: m.incomingActionDiameter,
                iconSize: m.incomingActionIcon,
                labelFontSize: m.controlLabelFont,
                background: const Color(0xFFE2554A),
                foreground: Colors.white,
                glow: true,
                onPressed: onDecline,
              ),
              CallGlassCircle(
                icon: Icons.call_rounded,
                label: tr('call_control_answer'),
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
