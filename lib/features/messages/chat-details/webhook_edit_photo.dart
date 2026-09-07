import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'group_edit_image_surfaces.dart';
import 'group_image_flow.dart';

/// The feed's picture inside the group edit sheet.
///
/// A feed cannot use [GroupEditImages], and the reason is not cosmetic: that
/// flow uploads through the conversation's own attachment presign, and the
/// server denies an attachment upload to a conversation nobody may post into.
/// Picking a photo for a feed there ended in a 403 the moment the crop was
/// confirmed. The webhook's own presign is gated on managing the feed instead
/// of on sending to it, which is the permission that actually applies.
///
/// One picture, no banner. A feed's photo is the face stamped on every message
/// it posts, and a second one set elsewhere would only compete with it.
class WebhookEditPhoto extends ConsumerStatefulWidget {
  const WebhookEditPhoto({super.key, required this.conversation});

  final ChatConversation conversation;

  @override
  ConsumerState<WebhookEditPhoto> createState() => _WebhookEditPhotoState();
}

class _WebhookEditPhotoState extends ConsumerState<WebhookEditPhoto> {
  bool _busy = false;

  /// Reported inside the sheet, not as a toast: a sheet is drawn over the
  /// toast layer for as long as it is open, so a failure there is invisible
  /// and indistinguishable from a save that simply has not refreshed yet.
  String? _error;

  /// The sheet outlives the upload, so the saved URL is read back from the
  /// store rather than from the conversation this widget was built with.
  ChatConversation get _conversation =>
      ref.watch(chatProvider).conversationById(widget.conversation.id) ??
      widget.conversation;

  Future<void> _edit() async {
    if (_busy) return;
    final cropped = await pickGroupImage(context, GroupImageKind.photo);
    if (cropped == null || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(chatProvider.notifier)
          .setWebhookAvatar(widget.conversation, cropped);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not update the photo: $error');
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: GroupPhotoSurface(
            conversation: _conversation,
            size: 96,
            colors: colors,
            busy: _busy,
            onTap: _edit,
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: TextStyle(fontSize: 12, color: colors.error),
            ),
          ),
      ],
    );
  }
}
