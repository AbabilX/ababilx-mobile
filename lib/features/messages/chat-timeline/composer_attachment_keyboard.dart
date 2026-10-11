import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/media/device_gallery.dart';
import '../chat-list/filter_reorder_blur.dart';
import 'composer_attach_chips.dart';
import 'composer_attach_order.dart';
import 'composer_media_rail.dart';

/// Signal's attachment keyboard: your recent media in a strip, and the
/// destinations that are not the library underneath it.
///
/// It sits in the keyboard's place rather than over the conversation, so the
/// thread stays visible while you pick — which is the whole point of it not
/// being a modal sheet.
class ComposerAttachmentKeyboard extends StatelessWidget {
  const ComposerAttachmentKeyboard({
    super.key,
    required this.galleryLabel,
    required this.cameraLabel,
    required this.fileLabel,
    required this.onGallery,
    required this.onCamera,
    required this.onFile,
    required this.onPickMedia,
    this.selectedMediaUris = const [],
    this.khaamLabel = 'Khaam',
    this.onKhaam,
    this.ghostLabel = 'Ghost Chat',
    this.onGhost,
    this.snippetLabel = 'Snippet',
    this.onSnippet,
    this.taskLabel = 'Task',
    this.onTask,
  });

  final String galleryLabel;
  final String cameraLabel;
  final String fileLabel;

  /// Null hides the chip: a group admin switched that kind off (server
  /// 0157). The rail goes with Gallery — it only ever holds photos and videos.
  final VoidCallback? onGallery;
  final VoidCallback? onCamera;
  final VoidCallback? onFile;

  /// Khaam greeting card. Null hides the chip — it is offered in a DM only.
  final String khaamLabel;
  final VoidCallback? onKhaam;

  /// Ghost Chat. Null hides the chip — a DM with an accepted connection only.
  final String ghostLabel;
  final VoidCallback? onGhost;

  /// Long text sent as a .md or .txt file. Null hides the chip — a group
  /// whose admins switched files off.
  final String snippetLabel;
  final VoidCallback? onSnippet;

  /// A task card for the other person. Null hides the chip — anywhere but a
  /// DM's main timeline.
  final String taskLabel;
  final VoidCallback? onTask;

  /// A tap straight on the rail, which skips the picker entirely.
  final ValueChanged<DeviceMediaItem> onPickMedia;
  final List<String> selectedMediaUris;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(height: 1, color: colors.outlineVariant),
            const SizedBox(height: 10),
            if (onGallery != null) ...[
              FilterReorderBlur(
                on: attachReordering,
                child: ComposerMediaRail(
                  onPick: onPickMedia,
                  selectedUris: selectedMediaUris,
                ),
              ),
              const SizedBox(height: 14),
            ],
            ComposerAttachChips(
              chips: {
                if (onGallery != null)
                  AttachDestination.gallery: AttachChipSpec(
                    label: galleryLabel,
                    icon: HugeIcons.strokeRoundedImage01,
                    onTap: onGallery!,
                  ),
                if (onCamera != null)
                  AttachDestination.camera: AttachChipSpec(
                    label: cameraLabel,
                    icon: HugeIcons.strokeRoundedCamera01,
                    onTap: onCamera!,
                  ),
                if (onFile != null)
                  AttachDestination.file: AttachChipSpec(
                    label: fileLabel,
                    icon: HugeIcons.strokeRoundedFile01,
                    onTap: onFile!,
                  ),
                if (onKhaam != null)
                  AttachDestination.khaam: AttachChipSpec(
                    label: khaamLabel,
                    icon: HugeIcons.strokeRoundedGift,
                    onTap: onKhaam!,
                  ),
                if (onGhost != null)
                  AttachDestination.ghost: AttachChipSpec(
                    label: ghostLabel,
                    icon: HugeIcons.strokeRoundedIncognito,
                    onTap: onGhost!,
                  ),
                if (onSnippet != null)
                  AttachDestination.snippet: AttachChipSpec(
                    label: snippetLabel,
                    icon: HugeIcons.strokeRoundedDocumentCode,
                    onTap: onSnippet!,
                  ),
                if (onTask != null)
                  AttachDestination.task: AttachChipSpec(
                    label: taskLabel,
                    icon: HugeIcons.strokeRoundedTaskAdd01,
                    onTap: onTask!,
                  ),
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
