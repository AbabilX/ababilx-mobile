import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'device_gallery.dart';

/// Decoded grid thumbnails, kept so a scroll back up does not re-decode.
///
/// Bounded on purpose: a library scrolled far enough would otherwise hold
/// hundreds of thumbnails alive. 300 tiles at ~12 KB each is a few megabytes,
/// which is the trade Signal makes for a grid that never flickers.
///
/// One entry per photo, holding the **largest** size anyone has asked for. The
/// surfaces want different sizes — the rail 320, the grid and folder gallery
/// 256 — and keying on size alone would decode the same picture once per
/// surface, while ignoring size entirely would hand a 320 px request a 256 px
/// thumbnail and draw it soft. So a cached copy serves any request no larger
/// than itself, and `cacheWidth` scales it down at decode time; a bigger
/// request misses and replaces the entry.
///
/// Least-recently-**used**, not first-inserted. Evicting by insertion order
/// throws away exactly the tiles a user scrolling back up is about to ask for
/// again, which is the one access pattern a thumbnail cache exists for; a read
/// re-inserts, so a Dart `Map` — which iterates in insertion order — gives LRU
/// for the cost of a remove.
class _ThumbCache {
  static const int _max = 300;
  static final Map<String, _Thumb> _entries = <String, _Thumb>{};

  static Uint8List? get(String uri, int maxPx) {
    final hit = _entries.remove(uri);
    if (hit == null) return null;
    _entries[uri] = hit;
    return hit.sizePx >= maxPx ? hit.bytes : null;
  }

  static void put(String uri, int maxPx, Uint8List bytes) {
    final existing = _entries[uri];
    if (existing != null && existing.sizePx > maxPx) return;
    _entries.remove(uri);
    if (_entries.length >= _max) _entries.remove(_entries.keys.first);
    _entries[uri] = _Thumb(bytes, maxPx);
  }
}

class _Thumb {
  const _Thumb(this.bytes, this.sizePx);

  final Uint8List bytes;
  final int sizePx;
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
    final cached = _ThumbCache.get(widget.item.uri, widget.maxPx);
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
    _ThumbCache.put(widget.item.uri, widget.maxPx, bytes);
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
      // Without this Flutter decodes the JPEG at its own dimensions and holds
      // that in the image cache — a second, larger copy of every tile.
      cacheWidth: widget.maxPx,
      errorBuilder: (_, _, _) =>
          ColoredBox(color: colors.surfaceContainerHighest),
    );
  }
}
