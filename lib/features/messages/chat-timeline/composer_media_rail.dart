import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/media/device_gallery.dart';
import '../../../shared/media/media_thumbnail.dart';

/// The strip of recent library media across the top of the attachment
/// keyboard, the way the reference app opens straight onto your last photos
/// instead of making you go through a picker first.
///
/// It renders nothing at all — not an empty state — when the library cannot
/// be read: on iOS, or with media permission denied, the shortcut row below
/// is the whole panel and the system picker is one tap away inside it.
class ComposerMediaRail extends StatefulWidget {
  const ComposerMediaRail({
    super.key,
    required this.onPick,
    this.selectedUris = const [],
    this.height = 132,
  });

  final ValueChanged<DeviceMediaItem> onPick;
  final List<String> selectedUris;
  final double height;

  @override
  State<ComposerMediaRail> createState() => _ComposerMediaRailState();
}

class _ComposerMediaRailState extends State<ComposerMediaRail> {
  List<DeviceMediaItem> _items = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (!await DeviceGallery.available()) return;
    final page = await DeviceGallery.page(limit: 40);
    if (mounted) setState(() => _items = page);
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: widget.height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, index) {
          final item = _items[index];
          final selection = widget.selectedUris.indexOf(item.uri);
          return _RailTile(
            item: item,
            selection: selection < 0 ? null : selection + 1,
            onTap: () => widget.onPick(item),
          );
        },
      ),
    );
  }
}

/// One recent item.
///
/// Draws through [MediaThumbnail] rather than fetching its own bytes, so the
/// panel's forty tiles share the one decoded-thumbnail cache with the grid
/// sheet and the folder gallery. Closing the "+" panel and opening it again
/// used to re-decode every tile from scratch.
class _RailTile extends StatelessWidget {
  const _RailTile({
    required this.item,
    required this.onTap,
    required this.selection,
  });

  final DeviceMediaItem item;
  final VoidCallback onTap;
  final int? selection;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 104,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: colors.surfaceContainerHighest),
              MediaThumbnail(item: item, maxPx: 320),
              if (selection != null)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: .18),
                      border: Border.all(color: colors.primary, width: 3),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              if (selection != null)
                Positioned(
                  top: 7,
                  right: 7,
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    child: Text(
                      '$selection',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              if (item.isVideo)
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Icon(
                    Icons.play_circle_fill,
                    size: 20,
                    color: colors.surface,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
