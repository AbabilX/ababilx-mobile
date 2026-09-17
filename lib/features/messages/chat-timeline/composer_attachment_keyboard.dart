import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/media/device_gallery.dart';
import '../chat_icon.dart';
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
    required this.contactLabel,
    required this.onGallery,
    required this.onCamera,
    required this.onFile,
    required this.onContact,
    required this.onPickMedia,
    this.selectedMediaUris = const [],
    this.jpackLabel = 'JPack',
    this.onJPack,
    this.ghostLabel = 'Ghost Chat',
    this.onGhost,
  });

  final String galleryLabel;
  final String cameraLabel;
  final String fileLabel;
  final String contactLabel;
  final VoidCallback onGallery;
  final VoidCallback onCamera;
  final VoidCallback onFile;
  final VoidCallback onContact;

  /// JPack greeting card. Null hides the chip — it is offered in a DM only.
  final String jpackLabel;
  final VoidCallback? onJPack;

  /// Ghost Chat. Null hides the chip — a DM with an accepted connection only.
  final String ghostLabel;
  final VoidCallback? onGhost;

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
            ComposerMediaRail(
              onPick: onPickMedia,
              selectedUris: selectedMediaUris,
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  AttachChip(
                    label: galleryLabel,
                    icon: HugeIcons.strokeRoundedImage01,
                    onTap: onGallery,
                  ),
                  AttachChip(
                    label: cameraLabel,
                    icon: HugeIcons.strokeRoundedCamera01,
                    onTap: onCamera,
                  ),
                  AttachChip(
                    label: fileLabel,
                    icon: HugeIcons.strokeRoundedFile01,
                    onTap: onFile,
                  ),
                  AttachChip(
                    label: contactLabel,
                    icon: HugeIcons.strokeRoundedUserCircle,
                    onTap: onContact,
                  ),
                  if (onJPack != null)
                    AttachChip(
                      label: jpackLabel,
                      icon: HugeIcons.strokeRoundedGift,
                      onTap: onJPack!,
                    ),
                  if (onGhost != null)
                    AttachChip(
                      label: ghostLabel,
                      icon: HugeIcons.strokeRoundedIncognito,
                      onTap: onGhost!,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

/// One rounded-square destination under the rail.
class AttachChip extends StatelessWidget {
  const AttachChip({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final List<List<dynamic>> icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: 76,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: ChatIcon(icon, size: 26, color: colors.onSurface),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
