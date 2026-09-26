import 'package:flutter/material.dart';

import '../data/khaam_covers.dart';
import 'khaam_cover_art.dart';

/// The Khaam envelope, portrait 1 : 1.6, as the receiver holds it: the upper
/// panel and the curved flap, with the [caption] written on the flap.
///
/// A memory [photo] fills the upper panel — cut by the flap's curve, so it
/// sits inside the envelope rather than on top of it — and the flap is drawn
/// over its lower edge. Until [photo] arrives the panel shows
/// the cover's motif; the switch is a slow cross-fade, which is the reveal.
class KhaamEnvelopeFace extends StatelessWidget {
  const KhaamEnvelopeFace({
    super.key,
    required this.cover,
    required this.width,
    this.photo,
    this.caption,
    this.overlay,
  });

  final KhaamCover cover;
  final double width;

  /// Sized to [khaamPhotoBox]; null shows the cover's own panel.
  final Widget? photo;

  /// Laid into [khaamCaptionBox] on the flap: the message, or the foil
  /// hiding it.
  final Widget? caption;

  /// Positioned children over the envelope (the compose screen's pills).
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final size = Size(width, width / khaamCoverAspect);
    final box = khaamPhotoBox(width);
    final captionBox = khaamCaptionBox(size);
    return ClipRRect(
      borderRadius: BorderRadius.circular(width * 0.06),
      child: SizedBox.fromSize(
        size: size,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: KhaamCoverPainter(cover: cover)),
            ),
            Positioned.fill(
              child: ClipPath(
                clipper: _UpperPanel(),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 650),
                    child: photo == null
                        ? const SizedBox.shrink(key: ValueKey('cover'))
                        : SizedBox.fromSize(
                            key: const ValueKey('photo'),
                            size: box,
                            child: photo,
                          ),
                  ),
                ),
              ),
            ),
            // The flap again, over the photo's lower edge, shadow and all.
            if (photo != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: KhaamCoverPainter(
                      cover: cover,
                      part: KhaamCoverPart.lower,
                    ),
                  ),
                ),
              ),
            if (caption != null)
              Positioned.fromRect(rect: captionBox, child: caption!),
            ?overlay,
          ],
        ),
      ),
    );
  }
}

class _UpperPanel extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => khaamUpperPath(size);

  @override
  bool shouldReclip(_UpperPanel old) => false;
}
