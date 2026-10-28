import 'package:flutter/material.dart';

import '../../khaam/data/khaam_payload.dart';
import '../../khaam/widgets/khaam_bubble.dart';
import '../../../shared/link-preview/link_preview_builder.dart';
import '../../../shared/link-preview/link_preview_data.dart';
import '../data/models/chat_models.dart';
import '../task/task_card.dart';
import '../task/task_card_data.dart';
import '../tiptap_plain_text.dart';
import 'message_body.dart';
import 'message_bubble.dart';
import 'message_bubble_footer.dart';
import 'message_link_preview.dart';
import 'message_quote_block.dart';
import 'quoted_bubble_layout.dart';
import 'signal_bubble_metrics.dart';
import 'sticker_media.dart';
import 'voice_bubble_footer.dart';
import '../../chat-lock/data/chat_lock_index.dart';

/// Image/video attachments only, no caption or quote — the media is the
/// surface, so [MessageBubble] paints no fill behind it.
///
/// Timed / expired photos (privacy mode) are label cards, not pictures — they
/// keep the bubble fill and put the time under the label, never on it.
bool isBareMediaBubble(ChatMessage message) {
  if (message.isDeleted) return false;
  if (message.quote != null) return false;
  if (message.forwardedFromName != null) return false;
  if (message.attachments.isEmpty) {
    if (!uploadingPreviewFillsBubble(message)) return false;
    if (message.pendingAttachments.any(_inputIsPdf)) return false;
    return tiptapToPlainText(message.body).trim().isEmpty;
  }
  if (!message.attachments.every((a) => a.isImage || a.isVideo)) return false;
  if (!_hasDrawableMedia(message.attachments)) return false;
  return tiptapToPlainText(message.body).trim().isEmpty;
}

/// A send that has not landed yet still draws as media when every pending
/// file is a photo, video, or PDF. The preview is the bubble.
bool uploadingPreviewFillsBubble(ChatMessage message) {
  if (message.isDeleted || message.quote != null) return false;
  if (message.attachments.isNotEmpty) return false;
  final pending = message.pendingAttachments;
  if (pending.isEmpty) return false;
  return pending.every(
    (attachment) =>
        looksLikeImage(attachment.contentType, attachment.fileName) ||
        looksLikeVideo(attachment.contentType, attachment.fileName) ||
        _inputIsPdf(attachment),
  );
}

bool _inputIsPdf(ChatAttachmentInput attachment) {
  final type = attachment.contentType.toLowerCase();
  return type == 'application/pdf' ||
      type == 'application/x-pdf' ||
      attachment.fileName.toLowerCase().endsWith('.pdf');
}

/// At least one attachment that is drawn as a real picture/video tile.
bool _hasDrawableMedia(List<ChatMessageAttachment> attachments) =>
    attachments.any((a) => !a.timed && !a.expired);

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
  /// needs the inset, so a quoted photo keeps the text-bubble path. Timed /
  /// expired-only attachments are label cards — not this path.
  bool get _isMediaBubble {
    if (message.isDeleted) return false;
    if (message.quote != null) return false;
    if (message.attachments.isEmpty) {
      return uploadingPreviewFillsBubble(message);
    }
    if (!message.attachments.every((a) => a.isImage || a.isVideo || a.isPdf)) {
      return false;
    }
    return _hasDrawableMedia(message.attachments);
  }

  /// A PDF page is white: the time over it takes the pill, never white ink.
  bool get _hasPdf =>
      message.attachments.any((a) => a.isPdf) ||
      message.pendingAttachments.any(_inputIsPdf);

  // Time + ticks always sit on the trailing edge of the bubble (WhatsApp /
  // common chat UI). An `Align` here instead would stretch the column to the
  // full width cap and every bubble would reach the far edge.
  static const CrossAxisAlignment _footerSide = CrossAxisAlignment.end;

  Widget? _footer({bool onMedia = false, bool onClear = false}) => showFooter
      ? MessageBubbleFooter(
          message: message,
          colors: colors,
          isOwn: isOwn,
          isSending: isSending,
          isFailed: isFailed,
          pulse: pulse,
          onMedia: onMedia,
          onClear: onClear,
        )
      : null;

  @override
  Widget build(BuildContext context) {
    final task = TaskCardData.of(message);
    if (task != null) return _task(task);
    // A Khaam rides inside an ordinary body (see `KhaamPayload`); it draws as
    // its card, edge to edge like media, with the footer under it.
    final khaam = message.isDeleted
        ? null
        : KhaamPayload.tryParse(message.body);
    if (khaam != null) return _khaam(khaam);
    // No link card in a locked chat: its picture and text would be cached
    // on disk, outside the lock.
    final previewUrl =
        message.isDeleted ||
            ChatLockIndex.cached.containsKey(message.conversationId)
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
        mediaFooter: _footer(
          onMedia: true,
          onClear:
              _hasPdf ||
              (isBareMediaBubble(message) && isStickerMessage(message)),
        ),
      );
    }

    final body = MessageBody(message: message, colors: colors);
    if (isVoiceBubble(message)) {
      return Padding(
        padding: _inset,
        child: VoiceBubbleFooter(footer: _footer(), child: body),
      );
    }

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

  /// A task card (server 0169): the bubble holds the card, which draws the
  /// text and files itself and puts the two dropdowns under them.
  Widget _task(TaskCardData task) => Padding(
    padding: _inset,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: TaskCard(
        message: message,
        task: task,
        colors: colors,
        footer: _footer(),
      ),
    ),
  );

  Widget _khaam(KhaamPayload payload) {
    final footer = _footer();
    return Column(
      crossAxisAlignment: _footerSide,
      mainAxisSize: MainAxisSize.min,
      children: [
        KhaamBubbleCard(message: message, payload: payload, isOwn: isOwn),
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
