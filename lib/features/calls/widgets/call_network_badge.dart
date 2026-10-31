import 'package:flutter/material.dart';

import '../../../core/localization/app_translations.dart';
import '../network/call_network_quality.dart';
import '../network/call_own_link_probe.dart';
import 'call_diagnostics_entry.dart';
import 'call_top_bar.dart' show callTextShadow;

/// Strength bars and a word for the 1:1 call's network.
///
/// [ownLink] is for a call that is still ringing or connecting: there is no
/// media path yet, so it shows this phone's own link to the server and keeps
/// it measured for as long as it is on screen. Otherwise it shows what the
/// connected call measured. Draws nothing until there is a reading.
class CallNetworkBadge extends StatefulWidget {
  const CallNetworkBadge({super.key, this.lang = 'en', this.ownLink = false});

  final String lang;
  final bool ownLink;

  @override
  State<CallNetworkBadge> createState() => _CallNetworkBadgeState();
}

class _CallNetworkBadgeState extends State<CallNetworkBadge> {
  static const _good = Color(0xFF4ADE80);
  static const _weak = Color(0xFFFFC53D);
  static const _poor = Color(0xFFFF6B5E);

  @override
  void initState() {
    super.initState();
    if (widget.ownLink) CallOwnLinkProbe.hold();
  }

  @override
  void didUpdateWidget(CallNetworkBadge old) {
    super.didUpdateWidget(old);
    if (widget.ownLink == old.ownLink) return;
    widget.ownLink ? CallOwnLinkProbe.hold() : CallOwnLinkProbe.release();
  }

  @override
  void dispose() {
    if (widget.ownLink) CallOwnLinkProbe.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        callOwnLinkQuality,
        callNetworkQuality,
        callVideoHeld,
      ]),
      builder: (context, _) {
        final level = widget.ownLink
            ? callOwnLinkQuality.value
            : callNetworkQuality.value;
        if (level == CallNetworkLevel.unknown) {
          return widget.ownLink
              ? const SizedBox.shrink()
              : const CallDiagnosticsEntry();
        }
        // With the camera held back the voice path may well read good; the
        // line has to say why the picture stopped instead.
        final held = !widget.ownLink && callVideoHeld.value;
        final (color, filled, key) = switch (level) {
          _ when held => (
            level == CallNetworkLevel.poor ? _poor : _weak,
            1,
            'call_network_video_paused',
          ),
          CallNetworkLevel.poor => (_poor, 1, 'call_network_poor'),
          CallNetworkLevel.weak => (_weak, 2, 'call_network_weak'),
          _ => (_good, 4, 'call_network_good'),
        };
        final text = AppTranslations.of(widget.lang, key);
        final badge = Semantics(
          label: text,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Bars(color: color, filled: filled),
                  const SizedBox(width: 6),
                  ExcludeSemantics(
                    child: Text(
                      text,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        shadows: callTextShadow,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        return widget.ownLink ? badge : CallDiagnosticsEntry(child: badge);
      },
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({required this.color, required this.filled});

  final Color color;
  final int filled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Container(
            width: 3,
            height: 5.0 + i * 3,
            decoration: BoxDecoration(
              color: i < filled ? color : Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        ],
      ],
    );
  }
}
