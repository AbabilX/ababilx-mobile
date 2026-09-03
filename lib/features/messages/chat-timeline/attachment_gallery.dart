import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/image_preview.dart';
import '../../../shared/widgets/image_preview_top_bar.dart';
import '../../../shared/widgets/image_preview_zoom.dart';
import '../../../shared/widgets/media_preview_actions.dart';
import '../../attachments/data/models/attachment_handle.dart';
import '../../attachments/providers/attachment_providers.dart';
import '../../attachments/widgets/attachment_download_badge.dart';
import '../../attachments/widgets/attachment_gate.dart';
import '../data/models/chat_models.dart';

/// The chat album viewer.
///
/// Unlike the wall's viewer this one never falls back to the network, so a
/// page whose bytes are not on the device has to offer the download itself —
/// which is what an album of eight needed: the images behind `+3` were
/// reachable by swipe and then simply blank, with no way to fetch them.
/// Each page is an [AttachmentGate], so the download badge, its progress and
/// the swap to the real image are the same ones the timeline uses.
Future<void> showChatAttachmentGallery(
  BuildContext context, {
  required List<ChatMessageAttachment> images,
  required int index,
}) {
  if (images.isEmpty) return Future.value();
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    builder: (_) => _ChatGalleryDialog(images: images, initialIndex: index),
  );
}

class _ChatGalleryDialog extends ConsumerStatefulWidget {
  const _ChatGalleryDialog({required this.images, required this.initialIndex});

  final List<ChatMessageAttachment> images;
  final int initialIndex;

  @override
  ConsumerState<_ChatGalleryDialog> createState() => _ChatGalleryDialogState();
}

class _ChatGalleryDialogState extends ConsumerState<_ChatGalleryDialog> {
  late final PageController _page;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.images.length - 1);
    _page = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.images[_index];
    // Only the current page's handle is watched — swiping repaints the bar,
    // a background download does not repaint the pager.
    final handle = ref.watch(attachmentHandleProvider(current)).valueOrNull;
    final localPath = handle?.isReady == true ? handle!.localPath : null;

    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              PageView.builder(
                controller: _page,
                itemCount: widget.images.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => _buildPage(widget.images[i]),
              ),
              Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: ImagePreviewTopBar(
                  image: PreviewImage(
                    fileUrl: current.fileUrl,
                    fileName: current.fileName,
                    localPath: localPath,
                  ),
                  index: _index,
                  total: widget.images.length,
                  allowRemoteFallback: false,
                ),
              ),
              if (localPath != null)
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: MediaPreviewCircleButton(
                    icon: Icons.ios_share_rounded,
                    tooltip: 'Share',
                    onTap: () => runMediaPreviewAction(
                      context,
                      MediaPreviewAction.share,
                      localPath: localPath,
                      remoteUrl: null,
                      fileName: current.fileName,
                    ),
                  ),
                ),
              Positioned(
                right: 16,
                bottom: 16,
                child: MediaPreviewCircleButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Close',
                  onTap: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(ChatMessageAttachment attachment) => Center(
    child: AttachmentGate(
      attachment: attachment,
      height: 220,
      borderRadius: 12,
      waiting: (context, handle) => _waiting(context, attachment, handle),
      ready: (context, handle) => ZoomablePreviewImage(
        image: PreviewImage(
          fileUrl: attachment.fileUrl,
          fileName: attachment.fileName,
          localPath: handle.localPath,
        ),
        allowRemoteFallback: false,
      ),
    ),
  );

  /// The gate's own placeholder is sized for a timeline tile and drawn on a
  /// light surface; on a black fullscreen page it needs its own shell.
  Widget _waiting(
    BuildContext context,
    ChatMessageAttachment attachment,
    AttachmentHandle? handle,
  ) {
    if (handle == null) {
      return const SizedBox(
        height: 220,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white54,
            ),
          ),
        ),
      );
    }
    return Container(
      height: 220,
      alignment: Alignment.center,
      child: AttachmentDownloadBadge(attachment: attachment, handle: handle),
    );
  }
}
