import 'dart:io';

import 'package:flutter/material.dart';

import '../media/video_thumbnail.dart';
import 'preview_icon.dart';
import 'video_thumb_states.dart';

/// A video bubble drawn from one extracted frame: an image, a play badge and
/// the running time. No decoder is held, so a timeline full of videos costs
/// exactly as much as a timeline full of photos.
class VideoPosterFrame extends StatelessWidget {
  const VideoPosterFrame({
    super.key,
    required this.thumb,
    required this.onTap,
    this.maxHeight = 288,
    this.borderRadius = 8,
  });

  final VideoThumb thumb;
  final VoidCallback onTap;
  final double maxHeight;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: AspectRatio(
          aspectRatio: thumb.aspectRatio,
          child: Material(
            color: Colors.black,
            child: InkWell(
              onTap: onTap,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(thumb.path),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: Colors.black,
                      child: PreviewIcon(
                        PreviewIcons.videoOff,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                  const Center(child: VideoPlayBadge()),
                  if (thumb.duration > Duration.zero)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: VideoDurationBadge(duration: thumb.duration),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
