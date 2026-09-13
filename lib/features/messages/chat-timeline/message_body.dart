import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat_models.dart';
import '../nickname/contact_nickname_provider.dart';
import '../providers/chat_provider.dart';
import '../tiptap_plain_text.dart';
import '../tiptap_viewer.dart';
import 'media-preview/chat_media_preview_meta.dart';
import 'message_attachments.dart';
import 'message_bubble.dart';
import 'message_long_body.dart';
import 'pending_message_attachments.dart';
import 'signal_bubble_metrics.dart';
import 'user_profile_sheet.dart';

class MessageBody extends ConsumerWidget {
  const MessageBody({super.key, required this.message, required this.colors});

  final ChatMessage message;

  /// Text sits on the bubble's fill, so every colour here comes from the
  /// bubble rather than straight off the scheme.
  final SignalBubbleColors colors;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.forwardedFromName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'Forwarded from ${message.forwardedFromName}',
              style: TextStyle(fontSize: 12, color: colors.muted),
            ),
          ),
        if (plain.isNotEmpty) _text(context, ref, collapsed: long),
        if (long)
          ReadMoreRow(
            body: message.body,
            colors: colors,
            editedAt: message.editedAt,
          ),
        if (message.attachments.isNotEmpty)
          MessageAttachments(
            attachments: message.attachments,
            withCaption: plain.isNotEmpty,
            preview: preview,
          ),
        if (message.isPending && message.pendingAttachments.isNotEmpty)
          PendingMessageAttachments(
            attachments: message.pendingAttachments,
            foreground: colors.foreground,
            muted: colors.muted,
            uploading: message.sendStatus == MessageSendStatus.uploading,
            progress: message.uploadProgress,
          ),
      ],
    );
  }

  /// The body itself. A collapsed one is clipped and faded out, and drops the
  /// "(edited)" marker with it — the marker trails the last block, which is
  /// exactly the part being cut off, and the full-screen view carries it.
  Widget _text(BuildContext context, WidgetRef ref, {required bool collapsed}) {
    final viewer = TiptapViewer(
      content: message.body,
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
      trailing: collapsed || message.editedAt == null
          ? null
          : TextSpan(
              text: ' (edited)',
              style: TextStyle(fontSize: 12, color: colors.muted),
            ),
    );
    return collapsed ? CollapsedBodyFade(child: viewer) : viewer;
  }
}
