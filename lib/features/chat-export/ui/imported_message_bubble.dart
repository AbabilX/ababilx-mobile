import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/file_preview_open.dart';
import '../../messages/chat_icon.dart';
import '../format/chat_export_format.dart';
import 'imported_time.dart';

/// One message of an imported chat: the timeline's single bubble fill, the
/// side telling who wrote it. Text is selectable; files open in another app.
class ImportedMessageBubble extends ConsumerWidget {
  const ImportedMessageBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.showSender,
    required this.chatDir,
  });

  final ExportedMessage message;
  final bool mine;
  final bool showSender;
  final String chatDir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = colors.onSurfaceVariant;
    if (message.kind == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 6),
        child: Text(
          message.text,
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 12),
        ),
      );
    }
    final reply = message.replyTo;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: EdgeInsets.fromLTRB(mine ? 48 : 12, 3, mine ? 12 : 48, 3),
        padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showSender && !mine)
              Text(
                message.sender,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (message.forwardedFrom != null)
              Text(
                '↪ ${message.forwardedFrom}',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            if (reply != null)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: colors.primary, width: 3),
                  ),
                ),
                child: Text(
                  [reply.sender, ?reply.text].join('\n'),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: muted, fontSize: 13),
                ),
              ),
            for (final f in message.files)
              _file(context, f, t('chat_imported_no_file')),
            if (message.text.isNotEmpty) SelectableText(message.text),
            const SizedBox(height: 2),
            Text(
              [
                importedTime(message.at),
                if (message.edited) t('chat_imported_edited'),
              ].join(' · '),
              style: TextStyle(color: muted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _file(BuildContext context, ExportedFile f, String missing) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final path = f.path == null ? null : '$chatDir/${f.path}';
    final image =
        path != null && (f.type.startsWith('image/') || _isImageName(f.name));
    void open() => openPreviewExternally(
      context,
      localPath: path,
      contentType: f.type.contains('x-ababilx-sealed') ? '' : f.type,
    );
    if (image) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: GestureDetector(
          onTap: open,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(path),
              cacheWidth: 600,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Text(f.name),
            ),
          ),
        ),
      );
    }
    return InkWell(
      onTap: path == null ? null : open,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            ChatIcon(HugeIcons.strokeRoundedFile01, size: 22, color: muted),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                path == null ? '${f.name} · $missing' : f.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static final _image = RegExp(
    r'\.(jpe?g|png|gif|webp|bmp|heic|heif)$',
    caseSensitive: false,
  );

  static bool _isImageName(String name) => _image.hasMatch(name);
}
