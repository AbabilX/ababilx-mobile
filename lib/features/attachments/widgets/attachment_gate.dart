import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/locked_file_placeholder.dart';
import '../../messages/data/models/chat_attachment.dart';
import '../data/models/attachment_handle.dart';
import '../providers/attachment_providers.dart';
import 'attachment_download_badge.dart';

/// Stands between a renderer and its bytes.
///
/// [ready] is only ever called with a handle whose local file exists, so every
/// renderer below this point can assume a real path and never deals with
/// download state, remote URLs or errors. Until then the gate holds the same
/// space the renderer will occupy — so a finished download swaps in place
/// instead of shoving the timeline around — and shows the download badge.
///
/// This is the only widget that watches an attachment's transfer state, which
/// is why a progress tick repaints one thumbnail rather than the message list.
class AttachmentGate extends ConsumerWidget {
  const AttachmentGate({
    super.key,
    required this.attachment,
    required this.ready,
    this.height = 160,
    this.width,
    this.borderRadius = 8,
    this.shape,
    this.showSize = true,
    this.waiting,
  });

  final ChatMessageAttachment attachment;
  final Widget Function(BuildContext context, AttachmentHandle handle) ready;
  final double height;
  final double? width;
  final double borderRadius;

  /// Album cells cut their corners individually; when set this wins over
  /// [borderRadius] so a placeholder has the same silhouette as the image it
  /// will be replaced by.
  final BorderRadius? shape;
  final bool showSize;
  final Widget Function(BuildContext context, AttachmentHandle? handle)?
  waiting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(attachmentHandleProvider(attachment));
    final handle = async.valueOrNull;

    if (attachment.locked || handle?.isLocked == true) {
      return LockedFilePlaceholder(fileName: attachment.fileName);
    }
    if (handle == null) {
      return waiting?.call(context, null) ?? _placeholder(context, null);
    }
    if (handle.isReady) return ready(context, handle);
    return waiting?.call(context, handle) ?? _placeholder(context, handle);
  }

  Widget _placeholder(BuildContext context, AttachmentHandle? handle) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: height,
      width: width,
      constraints: width == null ? const BoxConstraints(minWidth: 140) : null,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: shape ?? BorderRadius.circular(borderRadius),
      ),
      // No handle yet means the first frame before the local lookup returns —
      // showing a badge there would flash a download arrow on a file that is
      // already on disk.
      child: handle == null
          ? null
          : AttachmentDownloadBadge(
              attachment: attachment,
              handle: handle,
              showSize: showSize,
            ),
    );
  }
}
