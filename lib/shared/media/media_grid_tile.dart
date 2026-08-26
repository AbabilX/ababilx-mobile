import 'package:flutter/material.dart';

import 'device_gallery.dart';
import 'media_thumbnail.dart';

/// One square in the media grid.
///
/// Selection is shown as a numbered ring rather than a plain tick, because the
/// number is also the send order — the thing Signal's grid tells you that a
/// checkbox cannot.
class MediaGridTile extends StatelessWidget {
  const MediaGridTile({
    super.key,
    required this.item,
    required this.onTap,
    this.selectionIndex,
  });

  final DeviceMediaItem item;
  final VoidCallback onTap;
  final int? selectionIndex;

  String get _duration {
    final total = item.durationMs ~/ 1000;
    final minutes = total ~/ 60;
    final seconds = (total % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selected = selectionIndex != null;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MediaThumbnail(item: item),
          if (selected)
            ColoredBox(color: colors.primary.withValues(alpha: 0.28)),
          if (item.isVideo && item.durationMs > 0)
            Positioned(
              left: 6,
              bottom: 6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  child: Text(
                    _duration,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? colors.primary : Colors.black26,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: selected
                  ? Text(
                      '$selectionIndex',
                      style: TextStyle(
                        color: colors.onPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
