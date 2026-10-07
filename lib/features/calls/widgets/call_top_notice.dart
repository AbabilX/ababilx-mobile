import 'package:flutter/material.dart';

import 'call_note.dart';
import 'call_overlay_metrics.dart';

/// The top of the call screen: the peer's name and status while their video
/// or screen fills the stage, and under it the line saying this side is
/// sharing its screen. With no stage the name lives beside the avatar, so the
/// sharing line is all that is drawn here.
class CallTopNotice extends StatelessWidget {
  const CallTopNotice({
    super.key,
    required this.name,
    required this.status,
    required this.showPeer,
    this.sharingText,
  });

  final String name;
  final String status;
  final bool showPeer;

  /// Null while this side is not sharing its screen.
  final String? sharingText;

  static const _shadow = [Shadow(color: Color(0x66000000), blurRadius: 6)];

  @override
  Widget build(BuildContext context) {
    final m = CallOverlayMetrics.of(context);
    final sharing = sharingText;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showPeer) ...[
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: m.nameFont * 0.78,
              fontWeight: FontWeight.w600,
              shadows: _shadow,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: m.statusFont,
              shadows: _shadow,
            ),
          ),
        ],
        if (showPeer && sharing != null) const SizedBox(height: 8),
        if (sharing != null) CallNote(text: sharing),
      ],
    );
  }
}
