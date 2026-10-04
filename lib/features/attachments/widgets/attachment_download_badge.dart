import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/data/models/chat_attachment.dart';
import '../data/models/attachment_handle.dart';
import '../providers/attachment_providers.dart';
import '../services/attachment_authority.dart';
import 'attachment_size_label.dart';

/// The circular control that stands in for an attachment until its bytes are
/// on the device — WhatsApp's download ring, and the only new visible surface
/// this feature adds. Tap to download, tap again to cancel, tap to retry.
class AttachmentDownloadBadge extends ConsumerWidget {
  const AttachmentDownloadBadge({
    super.key,
    required this.attachment,
    required this.handle,
    this.showSize = true,
    this.compact = false,
  });

  final ChatMessageAttachment attachment;
  final AttachmentHandle handle;
  final bool showSize;

  /// The circle alone, never a caption under it. For a one-line row whose
  /// height is the circle's: "Cancel" under it overflowed every file row
  /// while it downloaded. The X inside the ring already says cancel.
  final bool compact;

  static const double _diameter = 44;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final authority = ref.read(attachmentAuthorityProvider);

    final size = handle.totalBytes > 0
        ? handle.totalBytes
        : attachment.sizeBytes;
    final label = compact
        ? ''
        : handle.isBusy
        ? AppTranslations.translate(context, ref, 'cancel')
        : showSize
        ? attachmentSizeLabel(size)
        : '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _circle(context, ref, colors, authority),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: handle.isBusy ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ],
    );
  }

  Widget _circle(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colors,
    AttachmentAuthority authority,
  ) {
    switch (handle.state) {
      case AttachmentTransferState.downloading:
      case AttachmentTransferState.queued:
        return _tappable(
          colors: colors,
          onTap: () => authority.cancel(attachment),
          tooltip: AppTranslations.translate(
            context,
            ref,
            'chat_attachment_cancel',
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: _diameter,
                height: _diameter,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  value:
                      handle.state == AttachmentTransferState.downloading &&
                          handle.progress > 0
                      ? handle.progress
                      : null,
                  color: colors.primary,
                ),
              ),
              Icon(Icons.close_rounded, size: 18, color: colors.onSurface),
            ],
          ),
        );

      case AttachmentTransferState.failed:
        return _tappable(
          colors: colors,
          onTap: () => authority.start(attachment),
          tooltip: handle.errorMessage.isEmpty
              ? AppTranslations.translate(context, ref, 'chat_attachment_retry')
              : handle.errorMessage,
          child: Icon(Icons.refresh_rounded, size: 22, color: colors.error),
        );

      case AttachmentTransferState.permanentlyFailed:
        return Tooltip(
          message: handle.errorMessage.isEmpty
              ? AppTranslations.translate(
                  context,
                  ref,
                  'chat_attachment_unavailable',
                )
              : handle.errorMessage,
          child: _shell(
            colors,
            Icon(
              Icons.error_outline_rounded,
              size: 22,
              color: colors.onSurfaceVariant,
            ),
          ),
        );

      case AttachmentTransferState.absent:
      case AttachmentTransferState.ready:
      case AttachmentTransferState.locked:
        return _tappable(
          colors: colors,
          onTap: () => authority.start(attachment),
          tooltip: AppTranslations.translate(
            context,
            ref,
            'chat_attachment_download',
          ),
          child: Icon(
            Icons.arrow_downward_rounded,
            size: 22,
            color: colors.primary,
          ),
        );
    }
  }

  Widget _tappable({
    required ColorScheme colors,
    required VoidCallback onTap,
    required String tooltip,
    required Widget child,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: _shell(colors, child)),
      ),
    );
  }

  Widget _shell(ColorScheme colors, Widget child) {
    return Container(
      width: _diameter,
      height: _diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surface.withValues(alpha: 0.82),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: child,
    );
  }
}
