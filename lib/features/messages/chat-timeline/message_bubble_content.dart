import 'package:flutter/material.dart';

import '../data/models/chat_models.dart';
import '../tiptap_plain_text.dart';
import 'message_body.dart';
import 'message_bubble.dart';
import 'message_bubble_footer.dart';
import 'message_quote_block.dart';
import 'signal_bubble_metrics.dart';

/// What sits inside a bubble, and how much padding it takes.
///
/// Signal lets a picture with no caption fill the bubble corner to corner and
/// pads only the footer under it; anything with text keeps the 12/7 inset on
/// every side. The bubble itself is always clipped, so both work with the same
/// container.
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

  /// A caption-less picture or video — the only case that loses its padding.
  /// A quote needs the inset, so a quoted photo keeps it.
  bool get _isMediaOnly {
    if (message.isDeleted) return false;
    if (message.quote != null) return false;
    if (message.attachments.isEmpty) return false;
    if (tiptapToPlainText(message.body).trim().isNotEmpty) return false;
    return message.attachments.every((a) => a.isImage || a.isVideo);
  }

  @override
  Widget build(BuildContext context) {
    const inset = EdgeInsets.fromLTRB(
      SignalBubbleMetrics.horizontalPadding,
      SignalBubbleMetrics.topPadding,
      SignalBubbleMetrics.horizontalPadding,
      SignalBubbleMetrics.bottomPadding,
    );

    final body = MessageBody(message: message, colors: colors);
    final quote = message.quote;
    final footer = showFooter
        ? MessageBubbleFooter(
            message: message,
            colors: colors,
            isOwn: isOwn,
            isSending: isSending,
            isFailed: isFailed,
            pulse: pulse,
          )
        : null;

    // Signal sets the footer against the bubble's own side — right on yours,
    // left on theirs. An `Align` here instead would stretch the column to the
    // full width cap and every bubble would reach the far edge.
    final footerSide = isOwn
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    if (_isMediaOnly) {
      return Column(
        crossAxisAlignment: footerSide,
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
      padding: inset,
      child: Column(
        crossAxisAlignment: footerSide,
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
}
