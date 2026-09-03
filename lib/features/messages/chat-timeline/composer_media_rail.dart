import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../shared/media/device_gallery.dart';

/// The strip of recent library media across the top of the attachment
/// keyboard, the way Signal opens straight onto your last photos instead of
/// making you go through a picker first.
///
/// It renders nothing at all — not an empty state — when the library cannot
/// be read: on iOS, or with media permission denied, the shortcut row below
/// is the whole panel and the system picker is one tap away inside it.
class ComposerMediaRail extends StatefulWidget {
  const ComposerMediaRail({super.key, required this.onPick, this.height = 132});

  final ValueChanged<DeviceMediaItem> onPick;
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
          return _RailTile(item: item, onTap: () => widget.onPick(item));
        },
      ),
    );
  }
}

class _RailTile extends StatefulWidget {
  const _RailTile({required this.item, required this.onTap});

  final DeviceMediaItem item;
  final VoidCallback onTap;

  @override
  State<_RailTile> createState() => _RailTileState();
}

class _RailTileState extends State<_RailTile> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final data = await DeviceGallery.thumbnail(widget.item.uri, maxPx: 320);
    if (mounted) setState(() => _bytes = data);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bytes = _bytes;
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 104,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: colors.surfaceContainerHighest),
              if (bytes != null)
                Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
              if (widget.item.isVideo)
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
