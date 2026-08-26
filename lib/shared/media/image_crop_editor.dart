import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'crop_transform.dart';

/// Signal's avatar editor: the photo under a circular window you drag and
/// pinch, and nothing else. No filters, no aspect-ratio menu — the only
/// decision an avatar needs is which part of the picture is the face.
///
/// Returns the cropped square as PNG bytes, or null if cancelled.
class ImageCropEditor extends StatefulWidget {
  const ImageCropEditor({
    super.key,
    required this.bytes,
    this.outputSize = 512,
    this.title = 'Move and scale',
  });

  final Uint8List bytes;
  final int outputSize;
  final String title;

  @override
  State<ImageCropEditor> createState() => _ImageCropEditorState();
}

class _ImageCropEditorState extends State<ImageCropEditor> {
  ui.Image? _image;
  double _scale = 1;
  Offset _offset = Offset.zero;
  double _gestureStartScale = 1;
  Offset _gestureStartOffset = Offset.zero;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _decode() async {
    final image = await decodeImageFromList(widget.bytes);
    if (!mounted) {
      image.dispose();
      return;
    }
    setState(() => _image = image);
  }

  CropTransform _transform(double viewport) => CropTransform(
    imageSize: Size(
      _image!.width.toDouble(),
      _image!.height.toDouble(),
    ),
    viewport: viewport,
    scale: _scale,
    offset: _offset,
  );

  Future<void> _save(double viewport) async {
    if (_image == null || _saving) return;
    setState(() => _saving = true);
    final bytes = await cropToPng(
      image: _image!,
      source: _transform(viewport).sourceRect,
      outputSize: widget.outputSize,
    );
    if (!mounted) return;
    Navigator.pop(context, bytes);
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
      ),
      body: image == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final viewport = constraints.biggest.shortestSide - 48;
                final transform = _transform(viewport);
                return Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: GestureDetector(
                          onScaleStart: (_) {
                            _gestureStartScale = _scale;
                            _gestureStartOffset = _offset;
                          },
                          onScaleUpdate: (details) {
                            setState(() {
                              _scale = (_gestureStartScale * details.scale)
                                  .clamp(
                                    CropTransform.minScale,
                                    CropTransform.maxScale,
                                  );
                              _offset = _transform(viewport).clamp(
                                _gestureStartOffset + details.focalPointDelta,
                              );
                            });
                          },
                          child: SizedBox(
                            width: viewport,
                            height: viewport,
                            child: ClipOval(
                              child: CustomPaint(
                                painter: _CropPainter(
                                  image: image,
                                  destination: transform.destinationRect,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: FilledButton(
                          onPressed: _saving ? null : () => _save(viewport),
                          child: Text(_saving ? 'Saving…' : 'Done'),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _CropPainter extends CustomPainter {
  const _CropPainter({required this.image, required this.destination});

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
  bool shouldRepaint(_CropPainter old) =>
      old.image != image || old.destination != destination;
}

/// Renders [source] out of [image] as a square PNG. Separated so the pixel
/// work can be reused (and tested) without the editor around it.
Future<Uint8List?> cropToPng({
  required ui.Image image,
  required Rect source,
  required int outputSize,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final side = outputSize.toDouble();
  canvas.drawImageRect(
    image,
    source,
    Rect.fromLTWH(0, 0, side, side),
    Paint()..filterQuality = FilterQuality.high,
  );
  final picture = recorder.endRecording();
  final rendered = await picture.toImage(outputSize, outputSize);
  picture.dispose();
  final data = await rendered.toByteData(format: ui.ImageByteFormat.png);
  rendered.dispose();
  return data?.buffer.asUint8List();
}
