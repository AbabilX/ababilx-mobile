import 'dart:io';

import 'package:flutter/material.dart';

/// Draws a preview picture from the copy on this device.
///
/// Every card goes through here rather than through an image widget pointed at
/// the web, which is the whole point of downloading it (see
/// `link_preview_image_store.dart`). The fallback is not decoration: the file
/// is in a pruned cache and can have been swept away since the metadata was
/// stored, so "the picture is gone" has to be an ordinary state.
class LinkPreviewPhoto extends StatelessWidget {
  const LinkPreviewPhoto({
    super.key,
    required this.path,
    required this.fallback,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String path;
  final Widget fallback;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => Image.file(
    File(path),
    width: width,
    height: height,
    fit: fit,
    // The bytes are already local, so a rebuild must not blink the picture out
    // and back while it is re-read.
    gaplessPlayback: true,
    errorBuilder: (_, _, _) => fallback,
  );
}
