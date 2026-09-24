import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/link-preview/link_preview_data.dart';
import '../../../shared/link-preview/link_preview_photo.dart';
import '../../../shared/link-preview/link_safety.dart';
import '../../../shared/widgets/link_preview.dart' show extractUrls;
import 'message_bubble.dart';
import 'signal_bubble_metrics.dart';

/// Signal-Android's link preview, inside the bubble.
///
/// Two layouts, and `hasBigImageLinkPreview` picks between them: a full-width
/// picture above the text when the image is at least
/// `media_bubble_min_width_solo` wide AND wider than it is tall, otherwise a
/// 72dp square at the start with the title set beside it. The landscape test is
/// what carries it — a square og:image is nearly always a logo, and a logo
/// stretched across the bubble reads as a rendering fault.
///
/// The card takes no colour of its own. Signal paints it with the bubble's own
/// fill (`setBackgroundColor(getDefaultBubbleColor(...))`), so it reads as part
/// of the message rather than a panel dropped into it, and it bleeds to the
/// bubble's edges — which is why it carries its own 12/6 padding instead of
/// sitting inside the bubble's inset.

/// The single URL a message unfurls, or null.
///
/// One preview per message, and **attachments win**: a message carrying a photo
/// shows the photo, never a card about a link underneath it.
String? messageLinkPreviewUrl({
  required String plainBody,
  required bool hasAttachments,
}) {
  if (hasAttachments || plainBody.trim().isEmpty) return null;
  for (final url in extractUrls(plainBody, max: 5)) {
    if (isValidPreviewUrl(url)) return url;
  }
  return null;
}

/// Signal's `MessageRecordUtil.hasBigImageLinkPreview`.
bool isBigImagePreview(LinkPreviewData preview) {
  final width = preview.imageWidth;
  final height = preview.imageHeight;
  if (preview.imagePath == null || width == null || height == null) {
    return false;
  }
  return width >= SignalBubbleMetrics.mediaMinWidthSolo && width > height;
}

Future<void> _open(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// The full-width picture of a big-image preview. Drawn as a sibling ABOVE the
/// text block, not inside it, so it reaches the bubble's clipped corners.
class MessageLinkPreviewImage extends StatelessWidget {
  const MessageLinkPreviewImage({
    super.key,
    required this.preview,
    required this.colors,
  });

  final LinkPreviewData preview;
  final SignalBubbleColors colors;

  @override
  Widget build(BuildContext context) {
    final width = preview.imageWidth!.toDouble();
    final height = preview.imageHeight!.toDouble();
    return GestureDetector(
      onTap: () => _open(preview.url),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final drawWidth = constraints.maxWidth;
          final scaled = drawWidth * height / width;
          return SizedBox(
            width: drawWidth,
            height: scaled.clamp(
              SignalBubbleMetrics.mediaMinHeight,
              SignalBubbleMetrics.mediaMaxHeight,
            ),
            child: LinkPreviewPhoto(
              path: preview.imagePath!,
              fallback: const SizedBox.shrink(),
            ),
          );
        },
      ),
    );
  }
}

/// Title, description and domain — plus the 72dp thumbnail when the picture is
/// not big enough to stand on its own above.
class MessageLinkPreviewCard extends StatelessWidget {
  const MessageLinkPreviewCard({
    super.key,
    required this.preview,
    required this.colors,
    required this.showThumbnail,
  });

  final LinkPreviewData preview;
  final SignalBubbleColors colors;
  final bool showThumbnail;

  @override
  Widget build(BuildContext context) {
    final title = preview.title;
    final description = preview.description;
    final thumbnail = showThumbnail ? preview.imagePath : null;

    return GestureDetector(
      onTap: () => _open(preview.url),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SignalBubbleMetrics.horizontalPadding,
          vertical: 6,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (thumbnail != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinkPreviewPhoto(
                      path: thumbnail,
                      width: 72,
                      height: 72,
                      fallback: ColoredBox(
                        color: colors.muted.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (title != null)
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                        color: colors.foreground,
                      ),
                    ),
                  ),
              ],
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description,
                // Caption only — long OG descriptions used to fill the bubble.
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.3,
                  color: colors.muted,
                ),
              ),
            ],
            const SizedBox(height: 2),
            Text(
              preview.siteName ?? previewDomain(preview.url),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: colors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
