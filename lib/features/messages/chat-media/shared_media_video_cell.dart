import 'dart:io';

import 'package:flutter/material.dart';

import '../../../shared/media/video_thumbnail.dart';

/// A video in the shared-media grid: the poster frame the platform already
/// extracted for the timeline, or a plate where it cannot.
///
/// It reuses [VideoThumbnails.forFile], which decodes once and caches to disk,
/// so a screen of videos holds **no** decoders — a live controller per cell
/// would drain the device-wide MediaCodec pool, which is the whole reason that
/// cache exists. A decoder is created only when one is opened.
class SharedMediaVideoCell extends StatefulWidget {
  const SharedMediaVideoCell({
    super.key,
    required this.localPath,
    required this.size,
    required this.radius,
    required this.onTap,
  });

  final String localPath;
  final double size;
  final BorderRadius radius;
  final VoidCallback onTap;

  @override
  State<SharedMediaVideoCell> createState() => _SharedMediaVideoCellState();
}

class _SharedMediaVideoCellState extends State<SharedMediaVideoCell> {
  late Future<VideoThumb?> _thumb;

  @override
  void initState() {
    super.initState();
    _thumb = VideoThumbnails.forFile(widget.localPath);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.radius,
      child: Material(
        color: Colors.black87,
        child: InkWell(
          onTap: widget.onTap,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              fit: StackFit.expand,
              children: [
                FutureBuilder<VideoThumb?>(
                  future: _thumb,
                  builder: (_, snapshot) {
                    final thumb = snapshot.data;
                    if (thumb == null) return const SizedBox.shrink();
                    return Image.file(
                      File(thumb.path),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    );
                  },
                ),
                const Center(
                  child: Icon(
                    Icons.play_circle_outline_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
