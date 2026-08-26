import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/locked_file_placeholder.dart';
import '../../../shared/widgets/network_video_player.dart';
import '../../../shared/widgets/pdf_preview.dart';
import '../../../shared/widgets/voice_url_player.dart';
import '../data/models/wall_models.dart';
import 'file_preview.dart';
import 'image_preview.dart';

/// Web parity ([wall-attachment-grid.tsx]):
/// - solo: max h = min(360, 55vw), hug aspect (no empty bars)
/// - multi: min row h = 170, width from aspect, **2 rows max**,
///   horizontal scroll for more columns, +N when >12 (like web)
class WallAttachmentGrid extends StatelessWidget {
  const WallAttachmentGrid({super.key, required this.attachments});

  final List<WallAttachment> attachments;

  static const double _soloMaxH = 360;
  static const double _rowH = 170;
  static const double _gap = 2;
  static const int _maxGridImages = 12;
  static const int _maxRows = 2;

  @override
  Widget build(BuildContext context) {
    final lockedFiles = attachments.where((a) => a.locked).toList();
    final open = attachments.where((a) => !a.locked).toList();
    final images = open.where((a) => a.isImage).toList();
    final videos = open.where((a) => a.isVideo).toList();
    final audio = open.where((a) => a.isAudio).toList();
    final pdfs = open
        .where((a) => !a.isImage && !a.isVideo && !a.isAudio && a.isPdf)
        .toList();
    final others = open
        .where((a) => !a.isImage && !a.isVideo && !a.isAudio && !a.isPdf)
        .toList();
    final scheme = Theme.of(context).colorScheme;
    final screenW = MediaQuery.sizeOf(context).width;

    final gridImages = images.take(_maxGridImages).toList();
    final hasOverflow = images.length > _maxGridImages;
    final overflowCount = images.length - (_maxGridImages - 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : screenW;
        final soloMaxH = _soloMaxH.clamp(0.0, screenW * 0.55);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (gridImages.length == 1)
              _WallImageThumb(
                url: gridImages.first.fileUrl,
                maxWidth: maxW,
                maxHeight: soloMaxH,
                placeholderColor: scheme.surfaceContainerHighest,
                onTap: () => showWallImagePreview(
                  context,
                  images: images,
                  initialIndex: 0,
                ),
              )
            else if (gridImages.isNotEmpty)
              ColoredBox(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                child: SizedBox(
                  // Exactly 2 rows — extra columns scroll on X.
                  height: _rowH * _maxRows + _gap * (_maxRows - 1),
                  width: double.infinity,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Wrap(
                      direction: Axis.vertical,
                      spacing: _gap,
                      runSpacing: _gap,
                      children: [
                        for (var i = 0; i < gridImages.length; i++)
                          _WallImageThumb(
                            url: gridImages[i].fileUrl,
                            // Multi: lock to min row height; width free from aspect.
                            fixedHeight: _rowH,
                            placeholderColor: scheme.surfaceContainerHighest,
                            overflowLabel:
                                hasOverflow && i == gridImages.length - 1
                                ? '+$overflowCount'
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
                ),
              ),
            for (final video in videos)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: NetworkVideoPlayer(
                  source: VideoSource.url(video.fileUrl),
                  fileName: video.fileName,
                  maxHeight: soloMaxH,
                  borderRadius: 12,
                ),
              ),
            for (final recording in audio)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 2),
                child: VoiceUrlPlayer(
                  source: AudioSourceRef.url(recording.fileUrl),
                  fileName: recording.fileName,
                  compact: true,
                ),
              ),
            // Web parity: first-page thumbnail card, hide filename in feed.
            for (final pdf in pdfs)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: PdfPreviewCard(
                  source: PdfDocumentSource.url(pdf.fileUrl),
                  fileName: pdf.fileName,
                  hideFileName: true,
                  height: 360,
                ),
              ),
            if (others.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final f in others)
                      _OtherFileChip(
                        attachment: f,
                        onTap: () => openWallFile(context, f),
                      ),
                  ],
                ),
              ),
            if (lockedFiles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final f in lockedFiles)
                      LockedFilePlaceholder(fileName: f.fileName),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

IconData _otherFileIcon(WallAttachment f) {
  final ct = f.contentType.toLowerCase();
  final name = f.fileName.toLowerCase();
  if (ct.contains('zip') ||
      ct.contains('tar') ||
      ct.contains('gzip') ||
      ct.contains('compress') ||
      RegExp(r'\.(zip|rar|7z|tar|gz)$').hasMatch(name)) {
    return Icons.folder_zip_outlined;
  }
  if (ct.contains('presentation') || RegExp(r'\.pptx?$').hasMatch(name)) {
    return Icons.slideshow_outlined;
  }
  if (ct.contains('spreadsheet') ||
      ct.contains('excel') ||
      RegExp(r'\.(xlsx?|csv)$').hasMatch(name)) {
    return Icons.grid_on_outlined;
  }
  if (ct.contains('word') || RegExp(r'\.docx?$').hasMatch(name)) {
    return Icons.description_outlined;
  }
  return Icons.insert_drive_file_outlined;
}

/// Web parity ([otherFiles] in wall-attachment-grid.tsx): bordered chip with
/// a type-specific icon, not a bare filename row.
class _OtherFileChip extends StatelessWidget {
  const _OtherFileChip({required this.attachment, required this.onTap});

  final WallAttachment attachment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_otherFileIcon(attachment), size: 16, color: scheme.primary),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  attachment.fileName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Solo: hug aspect inside maxW×maxH.
/// Multi: [fixedHeight] (min row h) + width = height × aspect (free).
class _WallImageThumb extends StatefulWidget {
  const _WallImageThumb({
    required this.url,
    required this.placeholderColor,
    required this.onTap,
    this.maxWidth,
    this.maxHeight,
    this.fixedHeight,
    this.overflowLabel,
  }) : assert(
         fixedHeight != null || (maxWidth != null && maxHeight != null),
         'Provide fixedHeight (multi) or maxWidth+maxHeight (solo)',
       );

  final String url;
  final Color placeholderColor;
  final VoidCallback onTap;
  final double? maxWidth;
  final double? maxHeight;
  final double? fixedHeight;
  final String? overflowLabel;

  bool get _isMulti => fixedHeight != null;

  @override
  State<_WallImageThumb> createState() => _WallImageThumbState();
}

class _WallImageThumbState extends State<_WallImageThumb> {
  double? _aspect; // width / height
  ImageStream? _stream;
  ImageStreamListener? _listener;

  static const double _minThumbW = 48;
  static const double _placeholderAspect = 96 / 170;

  @override
  void initState() {
    super.initState();
    _resolveAspect();
  }

  @override
  void didUpdateWidget(covariant _WallImageThumb oldWidget) {
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

  Size _sizeFor(double aspect) {
    if (widget._isMulti) {
      final h = widget.fixedHeight!;
      // Always fill min row height; width free from aspect.
      final w = (h * aspect).clamp(_minThumbW, double.infinity);
      return Size(w, h);
    }

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
    final aspect = _aspect ?? _placeholderAspect;
    final size = _sizeFor(aspect);
    final radius = widget._isMulti ? 4.0 : 12.0;

    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: widget.placeholderColor),
              CachedNetworkImage(
                imageUrl: widget.url,
                // Box already matches aspect — cover/contain look the same;
                // cover avoids sub-pixel letterbox on multi min-height.
                fit: widget._isMulti ? BoxFit.cover : BoxFit.contain,
                alignment: Alignment.center,
                width: size.width,
                height: size.height,
                placeholder: (_, _) => const SizedBox.expand(),
                errorWidget: (_, _, _) => const Center(
                  child: Icon(Icons.broken_image_outlined, size: 28),
                ),
              ),
              if (widget.overflowLabel != null)
                ColoredBox(
                  color: Colors.black54,
                  child: Center(
                    child: Text(
                      widget.overflowLabel!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
