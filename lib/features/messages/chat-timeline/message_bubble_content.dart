import 'package:flutter/material.dart';

import '../../jpack/data/jpack_payload.dart';
import '../../jpack/widgets/jpack_bubble.dart';
import '../../../shared/link-preview/link_preview_builder.dart';
import '../../../shared/link-preview/link_preview_data.dart';
import '../data/models/chat_models.dart';
import '../tiptap_plain_text.dart';
import 'message_body.dart';
import 'message_bubble.dart';
import 'message_bubble_footer.dart';
import 'message_link_preview.dart';
import 'message_quote_block.dart';
import 'quoted_bubble_layout.dart';
import 'signal_bubble_metrics.dart';

/// What sits inside a bubble, and how much padding it takes.
///
/// A picture or video fills the bubble corner to corner and draws the time on
/// the image (bottom-right) instead of a strip under it — caption or not. The
/// caption, if any, keeps the 12/7 inset below the media. Anything else with
/// text keeps the inset on every side. A link preview is the third case: it
/// bleeds to the edges like media and carries its own padding, so the inset
/// moves off the column and onto the parts that still want it. The bubble
/// itself is always clipped, so all three work with the same container.
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

  /// Picture/video bubble — caption or not. Time sits on the media. A quote
  /// needs the inset, so a quoted photo keeps the text-bubble path.
  bool get _isMediaBubble {
    if (message.isDeleted) return false;
    if (message.quote != null) return false;
    if (message.attachments.isEmpty) return false;
    return message.attachments.every((a) => a.isImage || a.isVideo);
  }

  // Signal sets the footer against the bubble's own side — right on yours,
  // left on theirs. An `Align` here instead would stretch the column to the
  // full width cap and every bubble would reach the far edge.
  CrossAxisAlignment get _footerSide =>
      isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start;

  Widget? _footer({bool onMedia = false}) => showFooter
      ? MessageBubbleFooter(
          message: message,
          colors: colors,
          isOwn: isOwn,
          isSending: isSending,
          isFailed: isFailed,
          pulse: pulse,
          onMedia: onMedia,
        )
      : null;

  @override
  Widget build(BuildContext context) {
    // A JPack rides inside an ordinary body (see `JPackPayload`); it draws as
    // its card, edge to edge like media, with the footer under it.
    final jpack = message.isDeleted
        ? null
        : JPackPayload.tryParse(message.body);
    if (jpack != null) return _jpack(jpack);
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
    if (_isMediaBubble) {
      return MessageBody(
        message: message,
        colors: colors,
        bleedMedia: true,
        mediaFooter: _footer(onMedia: true),
      );
    }

    final body = MessageBody(message: message, colors: colors);

    final footer = _footer();
    final quote = message.quote;
    final column = Column(
      crossAxisAlignment: _footerSide,
      mainAxisSize: MainAxisSize.min,
      children: [body, ?footer],
    );
    if (quote == null) return Padding(padding: _inset, child: column);
    return _quoted(
      quote: quote,
      content: Padding(padding: _inset.copyWith(top: 0), child: column),
    );
  }

  Widget _jpack(JPackPayload payload) {
    final footer = _footer();
    return Column(
      crossAxisAlignment: _footerSide,
      mainAxisSize: MainAxisSize.min,
      children: [
        JPackBubbleCard(message: message, payload: payload, isOwn: isOwn),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SignalBubbleMetrics.horizontalPadding,
              4,
              SignalBubbleMetrics.horizontalPadding,
              SignalBubbleMetrics.bottomPadding,
            ),
            child: footer,
          ),
      ],
    );
  }

  /// The quote above, everything else below, both exactly as wide as each
  /// other. A Column cannot express that without deciding the bubble's width
  /// first — see [QuotedBubbleLayout].
  Widget _quoted({required ChatMessageQuote quote, required Widget content}) =>
      QuotedBubbleLayout(
        quote: Padding(
          padding: _inset.copyWith(bottom: 0),
          child: MessageQuoteBlock(quote: quote, colors: colors, isOwn: isOwn),
        ),
        content: content,
      );

  /// Quote, then the card, then the author's own text under it — Signal's
  /// order. The card is what the message is about; the text is the comment on
  /// it.
  Widget _withPreview(LinkPreviewData preview) {
    final quote = message.quote;
    final big = isBigImagePreview(preview);
    final footer = _footer();

    final content = Column(
      crossAxisAlignment: _footerSide,
      mainAxisSize: MainAxisSize.min,
      children: [
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
    if (quote == null) return content;
    return _quoted(quote: quote, content: content);
  }
}
