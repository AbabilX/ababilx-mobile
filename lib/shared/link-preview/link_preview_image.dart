import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';

/// Measures a preview image before the card is built.
///
/// Signal-Android never has to: the SENDER attaches the thumbnail, so its width
/// and height arrive with the message and `hasBigImageLinkPreview` can read
/// them straight off the record. We fetch on the reader's device, so the size
/// is resolved here, once, and stored with the rest of the preview — measuring
/// it in the widget instead would draw the small card first and snap to the big
/// one a moment later, on every scroll past.
///
/// The resolve goes through the same provider the card will draw with, so the
/// bytes land in the image cache and the visible load is a cache hit.
Future<ui.Size?> resolvePreviewImageSize(
  String url, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final completer = Completer<ui.Size?>();
  final stream = CachedNetworkImageProvider(url).resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;

  void finish(ui.Size? size) {
    if (completer.isCompleted) return;
    stream.removeListener(listener);
    completer.complete(size);
  }

  listener = ImageStreamListener(
    (info, _) {
      final size = ui.Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
      info.dispose();
      finish(size);
    },
    // A picture that will not load is not a failure of the card: the title and
    // the domain are still worth drawing, so the size simply stays unknown.
    onError: (_, _) => finish(null),
  );

  stream.addListener(listener);
  return completer.future.timeout(timeout, onTimeout: () {
    finish(null);
    return null;
  });
}
