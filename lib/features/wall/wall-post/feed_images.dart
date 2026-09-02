import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../data/models/wall_models.dart';
import 'image_preview.dart';

/// Web parity for [wall-feed-images.tsx]:
/// - 1 image → hug aspect, max h = min(360, 55vw)
/// - 2 images + first wide (≥ 1.45) → stacked aspect-video
/// - else → packed gallery: 1 row if all fit, else 2 rows; +N overflow
class WallFeedImages extends StatelessWidget {
  const WallFeedImages({super.key, required this.images});

  final List<WallAttachment> images;

  static const double _soloMaxH = 360;
  static const double _wideRatio = 1.45;
  static const double _gap = 2;
  static const double _portraitAspect = 9 / 16;
  static const double _minThumbW = 72;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();

    final screenW = MediaQuery.sizeOf(context).width;
    final galleryH = _soloMaxH.clamp(0.0, screenW * 0.55);

    if (images.length == 1) {
      return _SoloImage(
        image: images.first,
        allImages: images,
        maxHeight: galleryH,
      );
    }

    return _WideOrPacked(
      images: images,
      galleryH: galleryH,
      wideRatio: _wideRatio,
      gap: _gap,
      portraitAspect: _portraitAspect,
      minThumbW: _minThumbW,
    );
  }
}

class _SoloImage extends StatelessWidget {
  const _SoloImage({
    required this.image,
    required this.allImages,
    required this.maxHeight,
  });

  final WallAttachment image;
  final List<WallAttachment> allImages;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        return Align(
          alignment: Alignment.centerLeft,
          child: _FeedTile(
            url: image.fileUrl,
            mode: _TileMode.solo,
            maxWidth: maxW,
            maxHeight: maxHeight,
            borderRadius: 12,
            alignment: Alignment.centerLeft,
            fit: BoxFit.contain,
            onTap: () => showWallImagePreview(
              context,
              images: allImages,
              initialIndex: 0,
            ),
          ),
        );
      },
    );
  }
}

class _WideOrPacked extends StatefulWidget {
  const _WideOrPacked({
    required this.images,
    required this.galleryH,
    required this.wideRatio,
    required this.gap,
    required this.portraitAspect,
    required this.minThumbW,
  });

  final List<WallAttachment> images;
  final double galleryH;
  final double wideRatio;
  final double gap;
  final double portraitAspect;
  final double minThumbW;

  @override
  State<_WideOrPacked> createState() => _WideOrPackedState();
}

class _WideOrPackedState extends State<_WideOrPacked> {
  bool? _firstWide;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _probeFirst();
  }

  @override
  void didUpdateWidget(covariant _WideOrPacked oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.images.first.fileUrl != widget.images.first.fileUrl ||
        oldWidget.images.length != widget.images.length) {
      _detach();
      _firstWide = null;
      _probeFirst();
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _detach() {
    final stream = _stream;
    final listener = _listener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _stream = null;
    _listener = null;
  }

  void _probeFirst() {
    if (widget.images.length != 2) {
      _firstWide = false;
      return;
    }
    final provider = CachedNetworkImageProvider(widget.images.first.fileUrl);
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        _detach();
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        if (!mounted || w <= 0 || h <= 0) return;
        setState(() => _firstWide = w / h >= widget.wideRatio);
      },
      onError: (_, _) {
        _detach();
        if (mounted) setState(() => _firstWide = false);
      },
    );
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    final stackWide = widget.images.length == 2 && _firstWide == true;
    if (stackWide) {
      // Outer corners only — full radius on each tile made the first image's
      // left side look oddly rounded top+bottom against the card.
      return Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _FeedTile(
              url: widget.images[0].fileUrl,
              mode: _TileMode.fill,
              borderRadius: 0,
              borderRadiusGeometry: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              alignment: Alignment.center,
              fit: BoxFit.cover,
              onTap: () => showWallImagePreview(
                context,
                images: widget.images,
                initialIndex: 0,
              ),
            ),
          ),
          SizedBox(height: widget.gap),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _FeedTile(
              url: widget.images[1].fileUrl,
              mode: _TileMode.fill,
              borderRadius: 0,
              borderRadiusGeometry: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
              alignment: Alignment.center,
              fit: BoxFit.cover,
              onTap: () => showWallImagePreview(
                context,
                images: widget.images,
                initialIndex: 1,
              ),
            ),
          ),
        ],
      );
    }

    // While probing a possible wide pair, fall through to packed (same as web
    // before firstWide resolves — avoids a layout jump for 3+ images).
    return _PackedGallery(
      images: widget.images,
      galleryH: widget.galleryH,
      gap: widget.gap,
      portraitAspect: widget.portraitAspect,
      minThumbW: widget.minThumbW,
    );
  }
}

class _PackedGallery extends StatelessWidget {
  const _PackedGallery({
    required this.images,
    required this.galleryH,
    required this.gap,
    required this.portraitAspect,
    required this.minThumbW,
  });

  final List<WallAttachment> images;
  final double galleryH;
  final double gap;
  final double portraitAspect;
  final double minThumbW;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: galleryH,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          if (width < 8 || height < 8) return const SizedBox.shrink();

          // Portrait aspect only estimates how many slots fit (web does the
          // same). Real thumb width follows each image's own aspect.
          int colsAt(int rowCount) {
            final rowH = height / rowCount;
            final thumbW = (rowH * portraitAspect).clamp(
              minThumbW,
              double.infinity,
            );
            return (width / thumbW).floor().clamp(1, 999);
          }

          final colsFull = colsAt(1);
          final int rows;
          final int cols;
          if (images.length <= colsFull) {
            rows = 1;
            cols = images.length.clamp(1, colsFull);
          } else {
            rows = 2;
            cols = colsAt(2);
          }

          final slots = cols * rows;
          final visible = images.take(slots).toList();
          final overflow = images.length - visible.length;
          final rowH = (height - gap * (rows - 1)) / rows;

          return OverflowBox(
            alignment: Alignment.topLeft,
            maxWidth: double.infinity,
            child: SizedBox(
              height: height,
              child: Wrap(
                direction: Axis.vertical,
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (var i = 0; i < visible.length; i++)
                    _RowThumb(
                      url: visible[i].fileUrl,
                      height: rowH,
                      minWidth: minThumbW,
                      fallbackAspect: portraitAspect,
                      overflowLabel: overflow > 0 && i == visible.length - 1
                          ? '+$overflow'
                          : null,
                      onTap: () => showWallImagePreview(
                        context,
                        images: images,
                        initialIndex: i,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// One packed-gallery cell: height locked to the row, width from aspect.
class _RowThumb extends StatefulWidget {
  const _RowThumb({
    required this.url,
    required this.height,
    required this.minWidth,
    required this.fallbackAspect,
    required this.onTap,
    this.overflowLabel,
  });

  final String url;
  final double height;
  final double minWidth;
  final double fallbackAspect;
  final VoidCallback onTap;
  final String? overflowLabel;

  @override
  State<_RowThumb> createState() => _RowThumbState();
}

class _RowThumbState extends State<_RowThumb> {
  double? _aspect;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _resolveAspect();
  }

  @override
  void didUpdateWidget(covariant _RowThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _detach();
      _aspect = null;
      _resolveAspect();
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _detach() {
    final stream = _stream;
    final listener = _listener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _stream = null;
    _listener = null;
  }

  void _resolveAspect() {
    final provider = CachedNetworkImageProvider(widget.url);
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        _detach();
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        if (!mounted || w <= 0 || h <= 0) return;
        setState(() => _aspect = w / h);
      },
      onError: (_, _) {
        _detach();
      },
    );
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    final aspect = _aspect ?? widget.fallbackAspect;
    final width = (widget.height * aspect).clamp(
      widget.minWidth,
      double.infinity,
    );
    return SizedBox(
      width: width,
      height: widget.height,
      child: _FeedTile(
        url: widget.url,
        mode: _TileMode.fill,
        borderRadius: 8,
        alignment: Alignment.topCenter,
        fit: BoxFit.cover,
        overflowLabel: widget.overflowLabel,
        onTap: widget.onTap,
      ),
    );
  }
}

enum _TileMode { solo, fill }

class _FeedTile extends StatefulWidget {
  const _FeedTile({
    required this.url,
    required this.mode,
    required this.borderRadius,
    required this.alignment,
    required this.fit,
    required this.onTap,
    this.borderRadiusGeometry,
    this.maxWidth,
    this.maxHeight,
    this.overflowLabel,
  });

  final String url;
  final _TileMode mode;
  final double borderRadius;
  final BorderRadiusGeometry? borderRadiusGeometry;
  final Alignment alignment;
  final BoxFit fit;
  final VoidCallback onTap;
  final double? maxWidth;
  final double? maxHeight;
  final String? overflowLabel;

  @override
  State<_FeedTile> createState() => _FeedTileState();
}

class _FeedTileState extends State<_FeedTile> {
  double? _aspect;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    if (widget.mode == _TileMode.solo) _resolveAspect();
  }

  @override
  void didUpdateWidget(covariant _FeedTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _detach();
      _aspect = null;
      if (widget.mode == _TileMode.solo) _resolveAspect();
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _detach() {
    final stream = _stream;
    final listener = _listener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _stream = null;
    _listener = null;
  }

  void _resolveAspect() {
    final provider = CachedNetworkImageProvider(widget.url);
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        _detach();
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        if (!mounted || w <= 0 || h <= 0) return;
        setState(() => _aspect = w / h);
      },
      onError: (_, _) {
        _detach();
      },
    );
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  Size _soloSize(double aspect) {
    final maxW = widget.maxWidth!;
    final maxH = widget.maxHeight!;
    var w = maxW;
    var h = w / aspect;
    if (h > maxH) {
      h = maxH;
      w = h * aspect;
    }
    return Size(w, h);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = scheme.surfaceContainerHighest;

    Widget image;
    if (widget.mode == _TileMode.solo) {
      final aspect = _aspect ?? 4 / 3;
      final size = _soloSize(aspect);
      image = SizedBox(
        width: size.width,
        height: size.height,
        child: CachedNetworkImage(
          imageUrl: widget.url,
          fit: widget.fit,
          alignment: widget.alignment,
          width: size.width,
          height: size.height,
          placeholder: (_, _) => ColoredBox(color: placeholder),
          errorWidget: (_, _, _) => ColoredBox(
            color: placeholder,
            child: const Center(
              child: Icon(Icons.broken_image_outlined, size: 28),
            ),
          ),
        ),
      );
    } else {
      image = CachedNetworkImage(
        imageUrl: widget.url,
        fit: widget.fit,
        alignment: widget.alignment,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, _) => ColoredBox(color: placeholder),
        errorWidget: (_, _, _) => ColoredBox(
          color: placeholder,
          child: const Center(
            child: Icon(Icons.broken_image_outlined, size: 28),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius:
            widget.borderRadiusGeometry ??
            BorderRadius.circular(widget.borderRadius),
        child: Stack(
          fit: widget.mode == _TileMode.fill
              ? StackFit.expand
              : StackFit.loose,
          children: [
            image,
            if (widget.overflowLabel != null)
              const ColoredBox(color: Color(0x8C000000)),
            if (widget.overflowLabel != null)
              Center(
                child: Text(
                  widget.overflowLabel!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
