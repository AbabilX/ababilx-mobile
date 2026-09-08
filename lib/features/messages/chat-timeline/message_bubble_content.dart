import 'package:flutter/material.dart';

import '../../../shared/link-preview/link_preview_builder.dart';
import '../../../shared/link-preview/link_preview_data.dart';
import '../data/models/chat_models.dart';
import '../tiptap_plain_text.dart';
import 'message_body.dart';
import 'message_bubble.dart';
import 'message_bubble_footer.dart';
import 'message_link_preview.dart';
import 'message_quote_block.dart';
import 'signal_bubble_metrics.dart';

/// What sits inside a bubble, and how much padding it takes.
///
/// Signal lets a picture with no caption fill the bubble corner to corner and
/// pads only the footer under it; anything with text keeps the 12/7 inset on
/// every side. A link preview is the third case: it bleeds to the edges like
/// media and carries its own padding, so the inset moves off the column and
/// onto the parts that still want it. The bubble itself is always clipped, so
/// all three work with the same container.
class MessageBubbleContent extends StatelessWidget {
  const MessageBubbleContent({
    super.key,
    required this.message,
    required this.colors,
    required this.isOwn,
    required this.isSending,
    required this.isFailed,
    required this.pulse,
    required this.showFooter,
  });

  final ChatMessage message;
  final SignalBubbleColors colors;
  final bool isOwn;
  final bool isSending;
  final bool isFailed;
  final Animation<double> pulse;
  final bool showFooter;

  static const _inset = EdgeInsets.fromLTRB(
    SignalBubbleMetrics.horizontalPadding,
    SignalBubbleMetrics.topPadding,
    SignalBubbleMetrics.horizontalPadding,
    SignalBubbleMetrics.bottomPadding,
  );

  /// A caption-less picture or video — the only case that loses its padding.
  /// A quote needs the inset, so a quoted photo keeps it.
  bool get _isMediaOnly {
    if (message.isDeleted) return false;
    if (message.quote != null) return false;
    if (message.attachments.isEmpty) return false;
    if (tiptapToPlainText(message.body).trim().isNotEmpty) return false;
    return message.attachments.every((a) => a.isImage || a.isVideo);
  }

  // Signal sets the footer against the bubble's own side — right on yours,
  // left on theirs. An `Align` here instead would stretch the column to the
  // full width cap and every bubble would reach the far edge.
  CrossAxisAlignment get _footerSide =>
      isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start;

  Widget? _footer() => showFooter
      ? MessageBubbleFooter(
          message: message,
          colors: colors,
          isOwn: isOwn,
          isSending: isSending,
          isFailed: isFailed,
          pulse: pulse,
        )
      : null;

  @override
  Widget build(BuildContext context) {
    final previewUrl = message.isDeleted
        ? null
        : messageLinkPreviewUrl(
            plainBody: tiptapToPlainText(message.body),
            hasAttachments: message.attachments.isNotEmpty,
          );
    if (previewUrl == null) return _plain();
    return LinkPreviewBuilder(
      url: previewUrl,
      builder: (context, preview) =>
          preview == null ? _plain() : _withPreview(preview),
    );
  }

  Widget _plain() {
    final body = MessageBody(message: message, colors: colors);
    final footer = _footer();
    final quote = message.quote;

    if (_isMediaOnly) {
      return Column(
        crossAxisAlignment: _footerSide,
        mainAxisSize: MainAxisSize.min,
        children: [
          body,
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
              child: footer,
            ),
        ],
      );
    }

    return Padding(
      padding: _inset,
      child: Column(
        crossAxisAlignment: _footerSide,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (quote != null)
            MessageQuoteBlock(quote: quote, colors: colors, isOwn: isOwn),
          body,
          ?footer,
        ],
      ),
    );
  }

  /// Quote, then the card, then the author's own text under it — Signal's
  /// order. The card is what the message is about; the text is the comment on
  /// it.
  Widget _withPreview(LinkPreviewData preview) {
    final quote = message.quote;
    final big = isBigImagePreview(preview);
    final footer = _footer();

    return Column(
      crossAxisAlignment: _footerSide,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (quote != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SignalBubbleMetrics.horizontalPadding,
              SignalBubbleMetrics.topPadding,
              SignalBubbleMetrics.horizontalPadding,
              0,
            ),
            child: MessageQuoteBlock(quote: quote, colors: colors, isOwn: isOwn),
          ),
        if (big) MessageLinkPreviewImage(preview: preview, colors: colors),
        MessageLinkPreviewCard(
          preview: preview,
          colors: colors,
          showThumbnail: !big,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SignalBubbleMetrics.horizontalPadding,
            0,
            SignalBubbleMetrics.horizontalPadding,
            SignalBubbleMetrics.bottomPadding,
          ),
          child: Column(
            crossAxisAlignment: _footerSide,
            mainAxisSize: MainAxisSize.min,
            children: [
              MessageBody(message: message, colors: colors),
              ?footer,
            ],
          ),
        ),
      ],
    );
  }
}
