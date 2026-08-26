import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'device_gallery.dart';

/// Decoded grid thumbnails, kept so a scroll back up does not re-decode.
///
/// Bounded on purpose: a library scrolled far enough would otherwise hold
/// hundreds of bitmaps alive. 300 tiles at ~12 KB each is a few megabytes,
/// which is the trade Signal makes for a grid that never flickers.
class _ThumbCache {
  static const int _max = 300;
  static final Map<String, Uint8List> _entries = <String, Uint8List>{};

  static Uint8List? get(String uri) => _entries[uri];

  static void put(String uri, Uint8List bytes) {
    if (_entries.length >= _max) {
      _entries.remove(_entries.keys.first);
    }
    _entries[uri] = bytes;
  }
}

/// A single library thumbnail, decoded natively at tile size.
class MediaThumbnail extends StatefulWidget {
  const MediaThumbnail({super.key, required this.item, this.maxPx = 256});

  final DeviceMediaItem item;
  final int maxPx;

  @override
  State<MediaThumbnail> createState() => _MediaThumbnailState();
}

class _MediaThumbnailState extends State<MediaThumbnail> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MediaThumbnail old) {
    super.didUpdateWidget(old);
    if (old.item.uri != widget.item.uri) _load();
  }

  Future<void> _load() async {
    final cached = _ThumbCache.get(widget.item.uri);
    if (cached != null) {
      setState(() => _bytes = cached);
      return;
    }
    setState(() => _bytes = null);
    final bytes = await DeviceGallery.thumbnail(
      widget.item.uri,
      maxPx: widget.maxPx,
    );
    if (!mounted || bytes == null) return;
    _ThumbCache.put(widget.item.uri, bytes);
    setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bytes = _bytes;
    if (bytes == null) {
      return ColoredBox(color: colors.surfaceContainerHighest);
    }
    return Image.memory(
      bytes,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) =>
          ColoredBox(color: colors.surfaceContainerHighest),
    );
  }
}
