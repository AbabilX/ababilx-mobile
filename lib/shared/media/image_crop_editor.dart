import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'crop_overlay.dart';
import 'crop_render.dart';
import 'crop_transform.dart';

/// The shape of the crop window. An avatar is a circle you drag a face into; a
/// banner is a wide strip. Nothing else about the editor differs, so the shape
/// is a parameter rather than a second screen.
enum CropShape { circle, wide }

/// Full-screen crop panel: the photo stays visible around the window, you
/// pinch and drag, then rotate / flip / reset before committing.
///
/// Returns the cropped JPEG, or null if cancelled.
class ImageCropEditor extends StatefulWidget {
  const ImageCropEditor({
    super.key,
    required this.bytes,
    this.shape = CropShape.circle,
    this.outputWidth = 512,
    this.title,
  });

  final Uint8List bytes;
  final CropShape shape;

  /// Longest edge of the exported image. The height follows from the shape.
  final int outputWidth;

  /// Defaults to "Edit photo" or "Edit cover" from [shape].
  final String? title;

  /// Width over height of the crop window. 3:1 is the ratio a header strip is
  /// actually drawn at, so what is framed here is what appears there.
  double get aspectRatio => shape == CropShape.circle ? 1 : 3;

  ui.Size get outputSize =>
      ui.Size(outputWidth.toDouble(), outputWidth / aspectRatio);

  String get resolvedTitle =>
      title ?? (shape == CropShape.wide ? 'Edit cover' : 'Edit photo');

  @override
  State<ImageCropEditor> createState() => _ImageCropEditorState();
}

class _ImageCropEditorState extends State<ImageCropEditor> {
  ui.Image? _image;
  double _scale = 1;
  Offset _offset = Offset.zero;
  double _gestureStartScale = 1;
  Offset _gestureStartOffset = Offset.zero;
  Offset _gestureStartFocal = Offset.zero;
  bool _busy = false;
  Size _viewport = Size.zero;

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

  /// The crop window, sized to the inner canvas (below the chrome, above the
  /// toolbar) and to the shape being cropped.
  Size _viewportFor(Size canvas) {
    final width = (canvas.width - 32).clamp(1.0, double.infinity);
    final height = width / widget.aspectRatio;
    final ceiling = (canvas.height - 24).clamp(1.0, double.infinity);
    if (height <= ceiling) return Size(width, height);
    return Size(ceiling * widget.aspectRatio, ceiling);
  }

  Rect _cropRect(Size canvas, Size viewport) => Rect.fromCenter(
    center: Offset(canvas.width / 2, canvas.height / 2),
    width: viewport.width,
    height: viewport.height,
  );

  void _reset() {
    setState(() {
      _scale = 1;
      _offset = Offset.zero;
    });
  }

  Future<void> _replaceImage(Future<ui.Image> Function(ui.Image) edit) async {
    final current = _image;
    if (current == null || _busy) return;
    setState(() => _busy = true);
    final next = await edit(current);
    if (!mounted) {
      next.dispose();
      return;
    }
    current.dispose();
    setState(() {
      _image = next;
      _scale = 1;
      _offset = Offset.zero;
      _busy = false;
    });
  }

  Future<void> _save() async {
    if (_image == null || _busy || _viewport == Size.zero) return;
    setState(() => _busy = true);
    final bytes = await cropToJpeg(
      image: _image!,
      source: _transform(_viewport).sourceRect,
      outputSize: widget.outputSize,
    );
    if (!mounted) return;
    Navigator.pop(context, bytes);
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    final padding = MediaQuery.paddingOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: image == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  SizedBox(height: padding.top + 8),
                  _Chrome(
                    title: widget.resolvedTitle,
                    onClose: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final canvas = Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        final viewport = _viewportFor(canvas);
                        _viewport = viewport;
                        final crop = _cropRect(canvas, viewport);
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            Positioned.fill(
                              child: _Canvas(
                                image: image,
                                crop: crop,
                                destination: _transform(
                                  viewport,
                                ).destinationRect,
                                onScaleStart: (details) {
                                  _gestureStartScale = _scale;
                                  _gestureStartOffset = _offset;
                                  _gestureStartFocal = details.localFocalPoint;
                                },
                                onScaleUpdate: (details) {
                                  setState(() {
                                    _scale =
                                        (_gestureStartScale * details.scale)
                                            .clamp(
                                              CropTransform.minScale,
                                              CropTransform.maxScale,
                                            );
                                    _offset = _transform(viewport)
                                        .offsetAfterPan(
                                          _gestureStartOffset,
                                          details.localFocalPoint -
                                              _gestureStartFocal,
                                        );
                                  });
                                },
                              ),
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: CropOverlayPainter(
                                    crop: crop,
                                    circle: widget.shape == CropShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  _Toolbar(
                    busy: _busy,
                    onRotate: () => _replaceImage(rotateUiImage90),
                    onFlip: () => _replaceImage(flipUiImageHorizontal),
                    onReset: _reset,
                    onDone: _save,
                  ),
                ],
              ),
      ),
    );
  }
}

/// The photo, positioned so [destination] is relative to [crop]'s origin —
/// the part outside the window stays visible under the dim overlay.
class _Canvas extends StatelessWidget {
  const _Canvas({
    required this.image,
    required this.crop,
    required this.destination,
    required this.onScaleStart,
    required this.onScaleUpdate,
  });

  final ui.Image image;
  final Rect crop;
  final Rect destination;
  final GestureScaleStartCallback onScaleStart;
  final GestureScaleUpdateCallback onScaleUpdate;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: onScaleStart,
      onScaleUpdate: onScaleUpdate,
      child: CustomPaint(
        painter: _ImagePainter(
          image: image,
          crop: crop,
          destination: destination,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ImagePainter extends CustomPainter {
  const _ImagePainter({
    required this.image,
    required this.crop,
    required this.destination,
  });

  final ui.Image image;
  final Rect crop;
  final Rect destination;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(crop.left, crop.top);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      destination,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ImagePainter old) =>
      old.image != image || old.crop != crop || old.destination != destination;
}

class _Chrome extends StatelessWidget {
  const _Chrome({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          _RoundButton(
            icon: Icons.close_rounded,
            tooltip: 'Cancel',
            onPressed: onClose,
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.busy,
    required this.onRotate,
    required this.onFlip,
    required this.onReset,
    required this.onDone,
  });

  final bool busy;
  final VoidCallback onRotate;
  final VoidCallback onFlip;
  final VoidCallback onReset;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Pinch to zoom · drag to position',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _RoundButton(
                icon: Icons.rotate_90_degrees_cw_rounded,
                tooltip: 'Rotate',
                onPressed: busy ? null : onRotate,
              ),
              const SizedBox(width: 12),
              _RoundButton(
                icon: Icons.flip_rounded,
                tooltip: 'Flip',
                onPressed: busy ? null : onFlip,
              ),
              const SizedBox(width: 12),
              _RoundButton(
                icon: Icons.restart_alt_rounded,
                tooltip: 'Reset',
                onPressed: busy ? null : onReset,
              ),
              const Spacer(),
              FilledButton(
                onPressed: busy ? null : onDone,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                ),
                child: Text(busy ? 'Saving…' : 'Done'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Opacity(
      opacity: onPressed == null ? 0.4 : 1,
      child: Material(
        color: Colors.white.withValues(alpha: 0.16),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
