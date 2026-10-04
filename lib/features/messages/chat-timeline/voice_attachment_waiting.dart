import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/voice_flat_layout.dart';
import '../../attachments/data/models/attachment_handle.dart';
import '../../attachments/providers/attachment_providers.dart';
import '../../attachments/services/attachment_authority.dart';
import '../../attachments/widgets/attachment_size_label.dart';
import '../data/models/chat_models.dart';

/// A voice note that is not on the phone yet, drawn in the loaded player's own
/// shape: the download ring where play will be, unplayed bars, the size where
/// the clock will be. The generic gate badge (44dp ring over a label) did not
/// fit the row and overflowed until the file landed.
class VoiceAttachmentWaiting extends ConsumerWidget {
  const VoiceAttachmentWaiting({
    super.key,
    required this.attachment,
    required this.handle,
    this.trailing,
  });

  final ChatMessageAttachment attachment;

  /// Null for the first frame, before the local lookup answers: no control
  /// then, or a file already on disk would flash a download arrow.
  final AttachmentHandle? handle;

  /// The bubble's time and ticks, at the end of the size line.
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final handle = this.handle;
    final bytes = (handle?.totalBytes ?? 0) > 0
        ? handle!.totalBytes
        : attachment.sizeBytes;
    return VoiceRowFrame(
      leading: handle == null ? null : _control(context, ref, colors, handle),
      // Same seed as the loaded player, so the bars do not change shape when
      // the file lands.
      seed: attachment.fileUrl,
      progress: 0,
      label: bytes > 0 ? attachmentSizeLabel(bytes) : '',
      trailing: trailing,
    );
  }

  Widget _control(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colors,
    AttachmentHandle handle,
  ) {
    // Read on tap, not here: building must not construct the download stack.
    AttachmentAuthority authority() => ref.read(attachmentAuthorityProvider);
    String tr(String key) => AppTranslations.translate(context, ref, key);
    switch (handle.state) {
      case AttachmentTransferState.queued:
      case AttachmentTransferState.downloading:
        final value =
            handle.state == AttachmentTransferState.downloading &&
                handle.progress > 0
            ? handle.progress
            : null;
        return _button(
          tooltip: tr('chat_attachment_cancel'),
          onTap: () => authority().cancel(attachment),
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                strokeWidth: 2.5,
                value: value,
                color: colors.primary,
              ),
              Icon(Icons.close_rounded, size: 18, color: colors.onSurface),
            ],
          ),
        );
      case AttachmentTransferState.failed:
        return _button(
          tooltip: handle.errorMessage.isEmpty
              ? tr('chat_attachment_retry')
              : handle.errorMessage,
          onTap: () => authority().start(attachment),
          child: Icon(Icons.refresh_rounded, color: colors.error),
        );
      case AttachmentTransferState.permanentlyFailed:
        return Tooltip(
          message: handle.errorMessage.isEmpty
              ? tr('chat_attachment_unavailable')
              : handle.errorMessage,
          child: Icon(
            Icons.error_outline_rounded,
            color: colors.onSurfaceVariant,
          ),
        );
      case AttachmentTransferState.absent:
      case AttachmentTransferState.ready:
      case AttachmentTransferState.locked:
        return _button(
          tooltip: tr('chat_attachment_download'),
          onTap: () => authority().start(attachment),
          fill: colors.primary,
          child: Icon(Icons.arrow_downward_rounded, color: colors.onPrimary),
        );
    }
  }

  Widget _button({
    required String tooltip,
    required VoidCallback onTap,
    required Widget child,
    Color? fill,
  }) => Tooltip(
    message: tooltip,
    child: Material(
      color: fill ?? Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Center(child: child),
      ),
    ),
  );
}
