import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/image_preview.dart';
import '../../../shared/widgets/image_preview_chrome.dart';
import '../../../shared/widgets/image_preview_top_bar.dart';
import '../../../shared/widgets/image_preview_zoom.dart';
import '../../attachments/data/models/attachment_handle.dart';
import '../../attachments/providers/attachment_providers.dart';
import '../../attachments/widgets/attachment_download_badge.dart';
import '../../attachments/widgets/attachment_gate.dart';
import '../data/models/chat_models.dart';
import 'media-preview/chat_media_preview_footer.dart';
import 'media-preview/chat_media_preview_meta.dart';

/// The chat album viewer — Signal-Android's `MediaPreviewFragment`.
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
  ChatMediaPreviewMeta? preview,
}) {
  if (images.isEmpty) return Future.value();
  return showDialog<void>(
    context: context,
    barrierColor: ImagePreviewChrome.background,
    builder: (_) => _ChatGalleryDialog(
      images: images,
      initialIndex: index,
      preview: preview,
    ),
  );
}

class _ChatGalleryDialog extends ConsumerStatefulWidget {
  const _ChatGalleryDialog({
    required this.images,
    required this.initialIndex,
    this.preview,
  });

  final List<ChatMessageAttachment> images;
  final int initialIndex;
  final ChatMediaPreviewMeta? preview;

  @override
  ConsumerState<_ChatGalleryDialog> createState() => _ChatGalleryDialogState();
}

class _ChatGalleryDialogState extends ConsumerState<_ChatGalleryDialog> {
  late final PageController _page;
  late int _index;
  bool _chrome = true;
  final _turns = <int, int>{};

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

  void _toggleChrome() => setState(() => _chrome = !_chrome);

  void _rotate() {
    setState(() => _turns[_index] = ((_turns[_index] ?? 0) + 1) % 4);
  }

  void _jumpTo(int i) {
    if (i == _index) return;
    _page.animateToPage(
      i,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.images[_index];
    // Only the current page's handle is watched — swiping repaints the bar,
    // a background download does not repaint the pager.
    final handle = ref.watch(attachmentHandleProvider(current)).valueOrNull;
    final localPath = handle?.isReady == true ? handle!.localPath : null;
    final meta = widget.preview;

    return Dialog.fullscreen(
      backgroundColor: ImagePreviewChrome.background,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _page,
              itemCount: widget.images.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) =>
                  _buildPage(widget.images[i], _turns[i] ?? 0),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ImagePreviewChrome.layer(
                visible: _chrome,
                child: ImagePreviewTopBar(
                  fileName: current.fileName,
                  detail:
                      meta?.detail ??
                      (widget.images.length > 1
                          ? '${_index + 1} / ${widget.images.length}'
                          : null),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: ImagePreviewChrome.layer(
                visible: _chrome,
                child: ChatMediaPreviewFooter(
                  images: widget.images,
                  index: _index,
                  localPath: localPath,
                  fileName: current.fileName,
                  caption: meta?.caption,
                  onSelect: _jumpTo,
                  onRotate: _rotate,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(ChatMessageAttachment attachment, int quarterTurns) =>
      AttachmentGate(
        attachment: attachment,
        waiting: (context, handle) => _waiting(context, attachment, handle),
        ready: (context, handle) => ZoomablePreviewImage(
          image: PreviewImage(
            fileUrl: attachment.fileUrl,
            fileName: attachment.fileName,
            localPath: handle.localPath,
          ),
          allowRemoteFallback: false,
          quarterTurns: quarterTurns,
          onTap: _toggleChrome,
        ),
      );

  /// The gate's own placeholder is sized for a timeline tile and drawn on a
  /// light surface; on a dark fullscreen page it needs its own shell.
  Widget _waiting(
    BuildContext context,
    ChatMessageAttachment attachment,
    AttachmentHandle? handle,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleChrome,
      child: Center(
        child: handle == null
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white54,
                ),
              )
            : AttachmentDownloadBadge(attachment: attachment, handle: handle),
      ),
    );
  }
}
