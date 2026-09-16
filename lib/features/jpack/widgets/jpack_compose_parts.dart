import 'package:flutter/material.dart';

import '../data/jpack_covers.dart';
import 'jpack_cover_art.dart';

/// The card as it will arrive, message drawn over the cover.
class JPackCardPreview extends StatelessWidget {
  const JPackCardPreview({
    super.key,
    required this.cover,
    required this.message,
  });

  final JPackCover cover;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Hero(
        tag: 'jpack-cover-${cover.id}',
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: JPackCoverArt(
            key: ValueKey(cover.id),
            cover: cover,
            width: 200,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 26, 14, 0),
              child: Text(
                message,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cover.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  shadows: const [Shadow(blurRadius: 6, color: Colors.black38)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
