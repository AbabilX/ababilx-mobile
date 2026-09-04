import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'crop_render.dart';
import 'crop_transform.dart';

/// The shape of the crop window. An avatar is a circle you drag a face into; a
/// banner is a wide strip. Nothing else about the editor differs, so the shape
/// is a parameter rather than a second screen.
enum CropShape { circle, wide }

/// Signal's avatar editor: the photo under a window you drag and pinch, and
/// nothing else. No filters, no aspect-ratio menu — the only decision an
/// avatar needs is which part of the picture is the face, and the only
/// decision a banner needs is which strip of it to keep.
///
/// Returns the cropped image as JPEG bytes, or null if cancelled.
class ImageCropEditor extends StatefulWidget {
  const ImageCropEditor({
    super.key,
    required this.bytes,
    this.shape = CropShape.circle,
    this.outputWidth = 512,
    this.title = 'Move and scale',
  });

  final Uint8List bytes;
  final CropShape shape;

  /// Longest edge of the exported image. The height follows from the shape.
  final int outputWidth;
  final String title;

  /// Width over height of the crop window. 3:1 is the ratio a header strip is
  /// actually drawn at, so what is framed here is what appears there.
  double get aspectRatio => shape == CropShape.circle ? 1 : 3;

  ui.Size get outputSize =>
      ui.Size(outputWidth.toDouble(), outputWidth / aspectRatio);

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

  CropTransform _transform(Size viewport) => CropTransform(
    imageSize: Size(_image!.width.toDouble(), _image!.height.toDouble()),
    viewport: viewport,
    scale: _scale,
    offset: _offset,
  );

  /// The crop window, sized to the screen and to the shape being cropped.
  Size _viewportFor(BoxConstraints constraints) {
    // Both insets are subtractions, so a short viewport — split screen, a
    // landscape phone — can drive either below zero, and a negative SizedBox
    // asserts rather than degrading. A tiny window is ugly; a crash is worse.
    final width = (constraints.maxWidth - 48).clamp(1.0, double.infinity);
    final height = width / widget.aspectRatio;
    // A circle is bounded by the shorter screen edge; a wide strip never comes
    // close to the height, so only the circle needs the second clamp.
    final ceiling = (constraints.maxHeight - 160).clamp(1.0, double.infinity);
    if (height <= ceiling) return Size(width, height);
    return Size(ceiling * widget.aspectRatio, ceiling);
  }

  Future<void> _save(Size viewport) async {
    if (_image == null || _saving) return;
    setState(() => _saving = true);
    final bytes = await cropToJpeg(
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
                final viewport = _viewportFor(constraints);
                return Column(
                  children: [
                    Expanded(child: Center(child: _window(image, viewport))),
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

  Widget _window(ui.Image image, Size viewport) {
    final painted = SizedBox(
      width: viewport.width,
      height: viewport.height,
      child: CustomPaint(
        painter: CropPainter(
          image: image,
          destination: _transform(viewport).destinationRect,
        ),
      ),
    );
    return GestureDetector(
      onScaleStart: (_) {
        _gestureStartScale = _scale;
        _gestureStartOffset = _offset;
      },
      onScaleUpdate: (details) {
        setState(() {
          _scale = (_gestureStartScale * details.scale).clamp(
            CropTransform.minScale,
            CropTransform.maxScale,
          );
          _offset = _transform(
            viewport,
          ).clamp(_gestureStartOffset + details.focalPointDelta);
        });
      },
      child: widget.shape == CropShape.circle
          ? ClipOval(child: painted)
          : ClipRRect(borderRadius: BorderRadius.circular(12), child: painted),
    );
  }
}
