import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';
import 'ram_media_cache.dart';

/// One picture of a locked chat, fetched into memory ([RamMediaCache]) and
/// drawn from there. Never the attachment store, never a cached network
/// image: both would leave a copy on disk.
class RamPhotoTile extends StatefulWidget {
  const RamPhotoTile({
    super.key,
    required this.url,
    required this.size,
    this.radius = 8,
    this.onTap,
  });

  final String url;
  final Size size;
  final double radius;
  final VoidCallback? onTap;

  @override
  State<RamPhotoTile> createState() => _RamPhotoTileState();
}

class _RamPhotoTileState extends State<RamPhotoTile> {
  late Future<Uint8List> _bytes = RamMediaCache.fetch(widget.url);

  @override
  void didUpdateWidget(RamPhotoTile old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) _bytes = RamMediaCache.fetch(widget.url);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: SizedBox.fromSize(
        size: widget.size,
        child: ColoredBox(
          color: colors.surfaceContainerHighest,
          child: FutureBuilder<Uint8List>(
            future: _bytes,
            builder: (context, snap) {
              final bytes = snap.data;
              if (bytes != null) {
                return InkWell(
                  onTap: widget.onTap,
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    cacheWidth: (widget.size.width * dpr).round(),
                    errorBuilder: (_, _, _) => _icon(
                      HugeIcons.strokeRoundedImageNotFound01,
                      colors.onSurfaceVariant,
                    ),
                  ),
                );
              }
              if (snap.hasError) {
                return InkWell(
                  onTap: () =>
                      setState(() => _bytes = RamMediaCache.fetch(widget.url)),
                  child: _icon(
                    HugeIcons.strokeRoundedRefresh,
                    colors.onSurfaceVariant,
                  ),
                );
              }
              return const Center(
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _icon(List<List<dynamic>> icon, Color color) =>
      Center(child: ChatIcon(icon, color: color, size: 26));
}
