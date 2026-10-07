import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/text/byte_size.dart';
import '../../attachments/data/models/attachment_handle.dart';
import '../../attachments/widgets/attachment_download_badge.dart';
import '../../attachments/widgets/attachment_gate.dart';
import '../chat_icon.dart';
import '../data/models/chat_models.dart';
import 'snippet_format.dart';
import 'snippet_viewer_screen.dart';

/// A `.md` / `.txt` attachment in a bubble: the file name, its size and the
/// first lines of the text. Tapping opens the whole file.
///
/// The height is fixed. A card that grew once its text was read would shove
/// every row above it, the scroll jitter the media tiles were cured of.
class SnippetCard extends StatelessWidget {
  const SnippetCard({super.key, required this.attachment, this.detail});

  final ChatMessageAttachment attachment;

  /// "You · 10:00 AM", shown under the file name in the viewer.
  final String? detail;

  static const double height = 136;
  static const double maxWidth = 280;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: maxWidth),
      child: AttachmentGate(
        attachment: attachment,
        reserveSpace: true,
        height: height,
        width: double.infinity,
        showSize: false,
        waiting: (_, handle) => _shell(context, handle: handle),
        ready: (_, handle) =>
            _shell(context, handle: handle, localPath: handle.localPath),
      ),
    ),
  );

  Widget _shell(
    BuildContext context, {
    required AttachmentHandle? handle,
    String? localPath,
  }) {
    final colors = Theme.of(context).colorScheme;
    final ready = localPath != null && localPath.isNotEmpty;
    return Material(
      color: colors.onSurface.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: !ready
            ? null
            : () => openSnippetViewer(
                context,
                fileName: attachment.fileName,
                localPath: localPath,
                detail: detail,
              ),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(context, colors),
                const SizedBox(height: 8),
                Expanded(
                  child: ready
                      ? _SnippetPreviewText(path: localPath)
                      : Center(
                          child: handle == null
                              ? null
                              : AttachmentDownloadBadge(
                                  attachment: attachment,
                                  handle: handle,
                                  showSize: false,
                                  compact: true,
                                ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, ColorScheme colors) => Row(
    children: [
      ChatIcon(
        snippetKindOf(attachment.fileName) == SnippetKind.markdown
            ? HugeIcons.strokeRoundedDocumentCode
            : HugeIcons.strokeRoundedNote01,
        size: 20,
        color: colors.primary,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          attachment.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        formatBytes(attachment.sizeBytes),
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
      ),
    ],
  );
}

/// The first lines of the file. Only the first 2 KB is read, whatever the
/// file's size, and the answer is kept so a row scrolling back draws at once.
class _SnippetPreviewText extends StatefulWidget {
  const _SnippetPreviewText({required this.path});

  final String path;

  @override
  State<_SnippetPreviewText> createState() => _SnippetPreviewTextState();
}

class _SnippetPreviewTextState extends State<_SnippetPreviewText> {
  static final Map<String, String> _known = {};
  static const int _headBytes = 2048;

  String? _text;

  @override
  void initState() {
    super.initState();
    _text = _known[widget.path];
    if (_text == null) _load();
  }

  Future<void> _load() async {
    final path = widget.path;
    String text;
    try {
      final head = <int>[];
      await for (final chunk in File(path).openRead(0, _headBytes)) {
        head.addAll(chunk);
      }
      text = snippetPreview(utf8.decode(head, allowMalformed: true));
    } catch (_) {
      text = '';
    }
    if (_known.length > 200) _known.clear();
    _known[path] = text;
    if (mounted && path == widget.path) setState(() => _text = text);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.topLeft,
      child: Text(
        _text ?? '',
        maxLines: 5,
        overflow: TextOverflow.fade,
        softWrap: false,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          height: 1.35,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
