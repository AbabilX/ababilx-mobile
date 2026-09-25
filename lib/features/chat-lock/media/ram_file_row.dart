import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/text/byte_size.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/video_fullscreen_dialog.dart';
import '../../../shared/widgets/video_source.dart';
import '../../ghost/native/ghost_blobs.dart';
import '../../messages/chat_icon.dart';
import '../../messages/data/models/chat_models.dart';
import 'ram_media_cache.dart';
import 'ram_pdf_viewer.dart';

/// A video, PDF or other file in a locked chat. Nothing is drawn from it
/// inline — a poster frame or a PDF thumbnail would need the file on disk.
///
/// Tapping it: a video streams from its URL (no local copy); a PDF is
/// fetched into memory and rendered natively; anything else is fetched into
/// memory and handed to the app the user picks through the memory provider,
/// which never writes a file.
class RamFileRow extends ConsumerStatefulWidget {
  const RamFileRow({super.key, required this.attachment});

  final ChatMessageAttachment attachment;

  @override
  ConsumerState<RamFileRow> createState() => _RamFileRowState();
}

class _RamFileRowState extends ConsumerState<RamFileRow> {
  bool _busy = false;

  String _t(String key) => AppTranslations.translate(context, ref, key);

  @override
  Widget build(BuildContext context) {
    final a = widget.attachment;
    final colors = Theme.of(context).colorScheme;
    final icon = a.isVideo
        ? HugeIcons.strokeRoundedVideo01
        : a.isPdf
        ? HugeIcons.strokeRoundedPdf01
        : HugeIcons.strokeRoundedFile01;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _busy ? null : _open,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _busy
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : ChatIcon(icon, size: 24, color: colors.onSurface),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (a.sizeBytes > 0)
                        Text(
                          formatBytes(a.sizeBytes),
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open() async {
    final a = widget.attachment;
    if (a.isVideo) {
      // Streamed by the player; the empty name keeps Save/Share off.
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) =>
              FullscreenVideoDialog(source: VideoSource.url(a.fileUrl)),
        ),
      );
      return;
    }
    if (a.sizeBytes > RamMediaCache.maxFileBytes) {
      showAppToast(context, _t('chatlock_file_too_big'), isError: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final bytes = await RamMediaCache.fetch(a.fileUrl);
      if (!mounted) return;
      final key = RamMediaCache.blobKey(a.fileUrl);
      if (a.isPdf) {
        await Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => RamPdfViewer(
              blobKey: key,
              bytes: bytes,
              fileName: a.fileName,
              cannotShow: _t('chatlock_file_cannot_open'),
            ),
          ),
        );
        return;
      }
      final mime = a.contentType.isEmpty
          ? 'application/octet-stream'
          : a.contentType;
      final opened = await GhostBlobs.open(a.fileName, mime, bytes, key: key);
      if (!opened && mounted) {
        showAppToast(context, _t('chatlock_file_cannot_open'), isError: true);
      }
    } catch (_) {
      if (mounted) {
        showAppToast(context, _t('chatlock_file_failed'), isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
