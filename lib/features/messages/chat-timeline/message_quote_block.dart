import 'package:flutter/material.dart';

import '../data/models/chat_models.dart';
import '../tiptap_plain_text.dart';
import 'message_bubble.dart';
import 'sender_name_color.dart';
import 'signal_bubble_metrics.dart';

/// Signal's quote block: the message being answered, inset at the top of the
/// bubble behind a coloured bar in the quoted sender's own name colour.
///
/// Tapping it does nothing yet — jumping to the original needs scroll-to-message
/// in the list, which does not exist here.
class MessageQuoteBlock extends StatelessWidget {
  const MessageQuoteBlock({
    super.key,
    required this.quote,
    required this.colors,
    required this.isOwn,
  });

  final ChatMessageQuote quote;
  final SignalBubbleColors colors;
  final bool isOwn;

  String get _preview {
    if (quote.deleted) return 'Original message not found';
    // The body is TipTap JSON, and a quote is a one-or-two-line preview, not a
    // rendered body — without this the block showed the raw `{"type":"doc"…`.
    final preview = tiptapToPreviewText(quote.body);
    if (preview.isNotEmpty) return preview;
    if (quote.isImage) return 'Photo';
    if (quote.isVideo) return 'Video';
    if (quote.isAudio) return 'Voice message';
    if (quote.attachmentType != null) return 'Attachment';
    return '';
  }

  IconData? get _icon {
    if (quote.deleted) return null;
    if (quote.isImage) return Icons.photo_outlined;
    if (quote.isVideo) return Icons.videocam_outlined;
    if (quote.isAudio) return Icons.mic_none_rounded;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = senderNameColor(quote.userId);
    final icon = _icon;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: const BorderRadius.all(
          Radius.circular(SignalBubbleMetrics.quoteInnerRadius),
        ),
        border: Border(
          left: BorderSide(
            color: accent,
            width: SignalBubbleMetrics.quoteBarWidth,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isOwn && quote.userName == null
                ? 'You'
                : (quote.userName ?? 'Unknown'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (_preview.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 14, color: colors.muted),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      _preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.25,
                        color: colors.muted,
                        fontStyle: quote.deleted
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
