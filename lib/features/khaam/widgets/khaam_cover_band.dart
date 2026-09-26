import 'package:flutter/material.dart';

import '../data/khaam_covers.dart';
import 'khaam_cover_art.dart';

/// The top of a cover — its motif — cut to [height], with a soft scrim at
/// the bottom so text laid over it ([child]) reads on every cover.
class KhaamCoverBand extends StatelessWidget {
  const KhaamCoverBand({
    super.key,
    required this.cover,
    required this.width,
    required this.height,
    this.child,
  });

  final KhaamCover cover;
  final double width;
  final double height;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topCenter,
                minHeight: 0,
                maxHeight: double.infinity,
                child: KhaamCoverArt(
                  cover: cover,
                  width: width,
                  part: KhaamCoverPart.upper,
                  showSeal: false,
                  radius: 0,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.45, 1],
                  colors: [
                    Colors.black.withValues(alpha: 0),
                    Colors.black.withValues(alpha: 0.38),
                  ],
                ),
              ),
            ),
          ),
          ?child,
        ],
      ),
    );
  }
}
