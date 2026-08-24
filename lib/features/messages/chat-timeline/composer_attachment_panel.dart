import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';

class ComposerAttachmentPanel extends StatelessWidget {
  const ComposerAttachmentPanel({
    super.key,
    required this.galleryLabel,
    required this.cameraLabel,
    required this.fileLabel,
    required this.contactLabel,
    required this.onGallery,
    required this.onCamera,
    required this.onFile,
    required this.onContact,
  });

  final String galleryLabel;
  final String cameraLabel;
  final String fileLabel;
  final String contactLabel;
  final VoidCallback onGallery;
  final VoidCallback onCamera;
  final VoidCallback onFile;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 190,
          child: Column(
            children: [
              Divider(height: 1, color: colors.outlineVariant),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _AttachmentAction(
                      label: galleryLabel,
                      icon: HugeIcons.strokeRoundedImage01,
                      onTap: onGallery,
                    ),
                    _AttachmentAction(
                      label: cameraLabel,
                      icon: HugeIcons.strokeRoundedCamera01,
                      onTap: onCamera,
                    ),
                    _AttachmentAction(
                      label: fileLabel,
                      icon: HugeIcons.strokeRoundedAttachment,
                      onTap: onFile,
                    ),
                    _AttachmentAction(
                      label: contactLabel,
                      icon: HugeIcons.strokeRoundedContactBook,
                      onTap: onContact,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentAction extends StatelessWidget {
  const _AttachmentAction({
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
    return Semantics(
      button: true,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 44,
        child: SizedBox(
          width: 76,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: ChatIcon(icon, size: 25, color: colors.onSurface),
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
    );
  }
}
