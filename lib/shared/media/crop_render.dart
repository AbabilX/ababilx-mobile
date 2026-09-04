import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Renders [source] out of [image] at [outputSize] as JPEG bytes.
///
/// Separated from the editor so the pixel work can be reused (and tested)
/// without a widget tree around it. [outputSize] carries the aspect ratio, so
/// a banner is exported wide rather than squeezed into a square.
///
/// JPEG rather than PNG because every one of these images is shown small — a
/// 48px row avatar, a header strip — and PNG is lossless, so a photographic
/// crop encodes to something like ten times the bytes for a difference nobody
/// can see at that size. Those bytes are paid for three times over: the upload,
/// the storage, and every member's device fetching it. Transparency is not lost
/// in the trade, because the crop always covers the whole window and the circle
/// is a mask applied at draw time, never baked into the file.
Future<Uint8List?> cropToJpeg({
  required ui.Image image,
  required ui.Rect source,
  required ui.Size outputSize,
  int quality = 82,
}) async {
  final width = outputSize.width.round();
  final height = outputSize.height.round();
  if (width <= 0 || height <= 0) return null;

  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawImageRect(
    image,
    source,
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..filterQuality = ui.FilterQuality.high,
  );
  final picture = recorder.endRecording();
  final rendered = await picture.toImage(width, height);
  picture.dispose();
  // Raw pixels rather than PNG: dart:ui cannot encode JPEG at all, so the
  // encoder below needs the samples, and asking for PNG here would mean
  // compressing once only to throw it away.
  final raw = await rendered.toByteData(format: ui.ImageByteFormat.rawRgba);
  rendered.dispose();
  if (raw == null) return null;

  // A full-size banner is a couple of megabytes of samples, and encoding that
  // on the UI isolate drops frames behind the saving spinner.
  return compute(
    _encodeJpeg,
    _JpegJob(
      pixels: raw.buffer.asUint8List(),
      width: width,
      height: height,
      quality: quality,
    ),
  );
}

class _JpegJob {
  const _JpegJob({
    required this.pixels,
    required this.width,
    required this.height,
    required this.quality,
  });

  final Uint8List pixels;
  final int width;
  final int height;
  final int quality;
}

Uint8List _encodeJpeg(_JpegJob job) => img.encodeJpg(
  img.Image.fromBytes(
    width: job.width,
    height: job.height,
    bytes: job.pixels.buffer,
    numChannels: 4,
  ),
  quality: job.quality,
);

/// Paints the source image into the crop window at [destination]. The window
/// itself is clipped by the caller, so this only has to place the picture.
class CropPainter extends CustomPainter {
  const CropPainter({required this.image, required this.destination});

  final ui.Image image;
  final Rect destination;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      destination,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(CropPainter old) =>
      old.image != image || old.destination != destination;
}
