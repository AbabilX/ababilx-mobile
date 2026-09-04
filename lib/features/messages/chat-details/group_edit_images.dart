import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'group_edit_image_surfaces.dart';
import 'group_image_flow.dart';

/// The two pictures at the top of the group edit sheet: a wide banner with the
/// circular photo overlapping its bottom edge, which is how the details header
/// itself is laid out — what you set here is what you will see there.
///
/// Personal groups only. A workspace channel takes its identity from the team,
/// so there is nothing here for it to set.
class GroupEditImages extends ConsumerStatefulWidget {
  const GroupEditImages({super.key, required this.conversation});

  final ChatConversation conversation;

  @override
  ConsumerState<GroupEditImages> createState() => _GroupEditImagesState();
}

class _GroupEditImagesState extends ConsumerState<GroupEditImages> {
  /// Which picture is uploading, if any, and what went wrong if it did.
  /// Progress and failure are reported inside the sheet because a SnackBar is
  /// drawn behind it — an error there is invisible, and an invisible error is
  /// indistinguishable from the change simply not having happened.
  GroupImageKind? _busy;
  String? _error;

  /// The sheet outlives the PATCH, so the freshly saved URLs are read back from
  /// the store rather than from the conversation this widget was built with.
  ChatConversation get _conversation =>
      ref.watch(chatProvider).conversationById(widget.conversation.id) ??
      widget.conversation;

  Future<void> _edit(GroupImageKind kind) async {
    if (_busy != null) return;
    final cropped = await pickGroupImage(context, kind);
    if (cropped == null || !mounted) return;

    setState(() {
      _busy = kind;
      _error = null;
    });
    try {
      await uploadGroupImage(ref, widget.conversation.id, cropped, kind);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not update the ${kind.label}: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _conversation;
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          // The banner strip plus the half of the photo that hangs below it.
          height: _bannerHeight + _photoSize / 2,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: GroupBannerSurface(
                  url: conversation.bannerUrl,
                  height: _bannerHeight,
                  colors: colors,
                  busy: _busy == GroupImageKind.banner,
                  onTap: () => _edit(GroupImageKind.banner),
                ),
              ),
              Positioned(
                left: 16,
                top: _bannerHeight - _photoSize / 2,
                child: GroupPhotoSurface(
                  conversation: conversation,
                  size: _photoSize,
                  colors: colors,
                  busy: _busy == GroupImageKind.photo,
                  onTap: () => _edit(GroupImageKind.photo),
                ),
              ),
            ],
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

  static const double _bannerHeight = 116;
  static const double _photoSize = 76;
}
