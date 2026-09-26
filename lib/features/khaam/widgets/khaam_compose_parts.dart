import 'package:flutter/material.dart';

import '../data/khaam_covers.dart';
import 'khaam_cover_art.dart';

/// The card as it will arrive, message drawn over the cover.
class KhaamCardPreview extends StatelessWidget {
  const KhaamCardPreview({
    super.key,
    required this.cover,
    required this.message,
  });

  final KhaamCover cover;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Hero(
        tag: 'khaam-cover-${cover.id}',
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: KhaamCoverArt(
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
