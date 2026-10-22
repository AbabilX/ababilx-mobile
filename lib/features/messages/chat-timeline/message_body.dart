import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/data/models/chat_models.dart';
import '../nickname/contact_nickname_provider.dart';
import '../providers/chat_provider.dart';
import '../tiptap_plain_text.dart';
import '../tiptap_viewer.dart';
import 'media-preview/chat_media_preview_meta.dart';
import 'media_caption_layout.dart';
import 'message_attachments.dart';
import 'message_bubble.dart';
import 'message_long_body.dart';
import 'pending_message_attachments.dart';
import 'signal_bubble_metrics.dart';
import 'user_profile_sheet.dart';
import '../../chat-lock/media/ram_message_attachments.dart';
import '../../chat-lock/providers/chat_locks_provider.dart';

class MessageBody extends ConsumerWidget {
  const MessageBody({
    super.key,
    required this.message,
    required this.colors,
    this.bleedMedia = false,
    this.mediaFooter,
  });

  final ChatMessage message;

  /// Text sits on the bubble's fill, so every colour here comes from the
  /// bubble rather than straight off the scheme.
  final SignalBubbleColors colors;

  /// Picture/video bubbles: media fills the bubble, caption keeps the inset
  /// under it. Attachments then size like a caption-less tile (max width,
  /// height follows the file).
  final bool bleedMedia;

  /// Time + ticks drawn on the media, not under it. Null when the parent
  /// hides the footer.
  final Widget? mediaFooter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (message.isDeleted) {
      return Text(
        'This message was deleted',
        style: TextStyle(
          color: colors.muted,
          fontStyle: FontStyle.italic,
          fontSize: 15,
        ),
      );
    }
    final plain = tiptapToPlainText(message.body);
    final long = MessageLongBody.isLong(plain);
    final isOwn =
        message.userId ==
        ref.watch(chatProvider.select((s) => s.currentUserId));
    final senderName = ref
        .watch(contactNicknamesProvider)
        .resolve(userId: message.userId, name: message.userName);
    final preview = ChatMediaPreviewMeta.of(
      message: message,
      isOwn: isOwn,
      senderName: senderName,
    );
    // Media captions already span the picture's width — put "(edited)" on
    // that trailing edge. Plain text bubbles keep the inline trailing so a
    // short edited line does not stretch to the bubble cap.
    final editedInCaption =
        bleedMedia && !long && message.editedAt != null;
    final text = <Widget>[
      if (message.forwardedFromName != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            'Forwarded from ${message.forwardedFromName}',
            style: TextStyle(fontSize: 12, color: colors.muted),
          ),
        ),
      if (plain.isNotEmpty)
        _text(
          context,
          ref,
          collapsed: long,
          includeEdited: !editedInCaption,
        ),
      if (long)
        ReadMoreRow(
          body: message.body,
          colors: colors,
          editedAt: message.editedAt,
        ),
      if (editedInCaption)
        Text(
          '(edited)',
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 12, color: colors.muted),
        ),
    ];
    final caption = text.isEmpty
        ? null
        : bleedMedia
        ? Padding(
            padding: const EdgeInsets.fromLTRB(
              SignalBubbleMetrics.horizontalPadding,
              6,
              SignalBubbleMetrics.horizontalPadding,
              SignalBubbleMetrics.bottomPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: text,
            ),
          )
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: text);

    Widget? media;
    if (message.attachments.isNotEmpty) {
      // A locked chat's files never go through the attachment store, which
      // downloads to disk: memory only, see RamMessageAttachments.
      final Widget tiles =
          ref.watch(isChatLockedProvider(message.conversationId))
          ? RamMessageAttachments(attachments: message.attachments)
          : MessageAttachments(
              attachments: message.attachments,
              withCaption: !bleedMedia && plain.isNotEmpty,
              captioned: text.isNotEmpty,
              bleed: bleedMedia,
              preview: preview,
            );
      final overlay = mediaFooter;
      // Always the Stack, footer or not. The footer comes and goes as the
      // message joins or leaves a run; swapping the tree shape with it would
      // remount the tiles, and a remounted tile re-picks its frame.
      media = Stack(
        children: [
          tiles,
          if (overlay != null)
            Positioned(
              right: 8,
              bottom: 6,
              child: IgnorePointer(child: overlay),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (bleedMedia && media != null && caption != null)
          MediaCaptionLayout(media: media, caption: caption)
        else if (bleedMedia) ...[
          ?media,
          ?caption,
        ] else ...[
          ?caption,
          ?media,
        ],
        if (message.isPending && message.pendingAttachments.isNotEmpty)
          PendingMessageAttachments(
            attachments: message.pendingAttachments,
            foreground: colors.foreground,
            muted: colors.muted,
            uploading: message.sendStatus == MessageSendStatus.uploading,
            progress: message.uploadProgress,
            cancelLabel: AppTranslations.translate(context, ref, 'cancel'),
            onCancel: message.sendStatus == MessageSendStatus.uploading
                ? () => ref
                      .read(chatProvider.notifier)
                      .cancelUploadingMessage(
                        message.conversationId,
                        message.clientRef ?? message.id,
                        parentId: message.parentId,
                      )
                : null,
          ),
      ],
    );
  }

  /// The body itself. A collapsed one is clipped and faded out, and drops the
  /// "(edited)" marker with it — the marker trails the last block, which is
  /// exactly the part being cut off, and the full-screen view carries it.
  Widget _text(
    BuildContext context,
    WidgetRef ref, {
    required bool collapsed,
    bool includeEdited = true,
  }) {
    final viewer = TiptapViewer(
      content: message.body,
      markdown: true,
      // A mention is the one part of a body that names a person, so it opens
      // them — the same sheet the avatar and the sender line already open.
      onMentionTap: (userId, label) => showUserProfileSheet(
        context: context,
        ref: ref,
        userId: userId,
        userName: label,
      ),
      maxHeight: collapsed ? MessageLongBody.collapsedHeight : null,
      style: TextStyle(
        color: colors.foreground,
        fontSize: SignalBubbleMetrics.bodyTextSize,
        height: 1.35,
      ),
      trailing: !includeEdited || collapsed || message.editedAt == null
          ? null
          : TextSpan(
              text: ' (edited)',
              style: TextStyle(fontSize: 12, color: colors.muted),
            ),
    );
    return collapsed ? CollapsedBodyFade(child: viewer) : viewer;
  }
}
