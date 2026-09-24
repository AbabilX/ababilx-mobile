import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../shared/text/display_name.dart';
import 'call_overlay_metrics.dart';
import 'call_top_bar.dart' show callTextShadow;
import '../../../shared/widgets/avatar_cache.dart';

/// Circular peer face + name + status for the 1:1 call overlay.
///
/// Kept separate from [AppAvatar] (rounded-square) so chat and call surfaces
/// can evolve independently.
class CallPeerIdentity extends StatelessWidget {
  const CallPeerIdentity({
    super.key,
    required this.name,
    required this.status,
    this.avatarUrl,
    this.showWave = false,
  });

  final String name;
  final String status;
  final String? avatarUrl;
  final bool showWave;

  @override
  Widget build(BuildContext context) {
    final m = CallOverlayMetrics.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PeerFace(url: avatarUrl, name: name, diameter: m.avatarDiameter),
        SizedBox(height: m.design(40).clamp(18.0, 28.0)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: m.sideMargin),
          child: Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: m.nameFont,
              fontWeight: FontWeight.w600,
              height: 1.15,
              shadows: callTextShadow,
            ),
          ),
        ),
        SizedBox(height: m.design(18).clamp(8.0, 14.0)),
        Text(
          status,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: m.statusFont,
            fontWeight: FontWeight.w400,
            shadows: callTextShadow,
          ),
        ),
        if (showWave) ...[
          SizedBox(height: m.design(18).clamp(8.0, 14.0)),
          const _CallingWave(),
        ],
      ],
    );
  }
}

class _PeerFace extends StatelessWidget {
  const _PeerFace({
    required this.url,
    required this.name,
    required this.diameter,
  });

  final String? url;
  final String name;
  final double diameter;

  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
  };

  @override
  Widget build(BuildContext context) {
    final letter = displayNameInitial(name) ?? '?';
    final colors = Theme.of(context).colorScheme;
    final src = url?.trim();
    final hasPhoto = src != null && src.isNotEmpty;

    final placeholder = ColoredBox(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.85),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: diameter * 0.36,
            color: colors.onSurface,
          ),
        ),
      ),
    );

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.28),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.12),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipOval(
        child: hasPhoto
            ? CachedNetworkImage(
                cacheManager: AvatarCache.instance,
                imageUrl: src,
                fit: BoxFit.cover,
                httpHeaders: _headers,
                placeholder: (_, _) => placeholder,
                errorWidget: (_, _, _) => placeholder,
              )
            : placeholder,
      ),
    );
  }
}

/// Tiny three-bar pulse under "Calling…" — decorative only.
class _CallingWave extends StatefulWidget {
  const _CallingWave();

  @override
  State<_CallingWave> createState() => _CallingWaveState();
}

class _CallingWaveState extends State<_CallingWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              _bar(i),
            ],
          ],
        );
      },
    );
  }

  Widget _bar(int index) {
    final t = (_ctrl.value + index * 0.22) % 1.0;
    final h = 4.0 + 10.0 * (0.5 + 0.5 * (t < 0.5 ? t * 2 : 2 - t * 2));
    return Container(
      width: 3,
      height: h,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
