import 'package:flutter/material.dart';

import '../../../shared/widgets/app_toast.dart';
import '../data/models/chat_models.dart';
import '../tiptap_plain_text.dart';
import 'message_bubble.dart';
import 'sender_name_color.dart';
import 'signal_bubble_metrics.dart';
import 'timeline_jump.dart';

/// Signal's quote block: the message being answered, inset at the top of the
/// bubble behind a coloured bar in the quoted sender's own name colour.
///
/// Tapping it walks the timeline back to the message being answered — see
/// [TimelineJumpController]. There is nowhere to walk when the original is gone,
/// and no controller at all when a bubble is drawn outside a timeline (the
/// long-press overlay's floating copy), so the tap is simply absent there.
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

  bool get _unavailable =>
      quote.isEncrypted && quote.body == 'Unable to decrypt this message';

  String get _preview {
    if (quote.deleted) return 'Original message not found';
    // Sealed under a key this account was never given — typically written
    // before we joined the group. Not a failure worth alarming anyone over:
    // the reply itself reads fine.
    if (_unavailable) return 'Original message not available';
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

  /// Walks to the original, and says so when it cannot be reached — a tap that
  /// does nothing reads as a broken control.
  Future<void> _open(BuildContext context, TimelineJumpController jump) async {
    // The row this quote sits in can be recycled out from under the walk, so
    // the toast is anchored to the navigator rather than to this element.
    final host = Navigator.maybeOf(context)?.context ?? context;
    final reached = await jump.jumpTo(quote.messageId);
    if (reached || !host.mounted) return;
    showAppToast(host, 'Original message not found', isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = senderNameColor(quote.userId);
    final icon = _icon;
    final jump = TimelineJumpScope.maybeOf(context);
    final canOpen =
        jump != null && !quote.deleted && quote.messageId.isNotEmpty;

    final block = Container(
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
                        fontStyle: quote.deleted || _unavailable
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
    if (!canOpen) return block;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _open(context, jump),
      child: block,
    );
  }
}
