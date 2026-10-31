import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/voice_url_player.dart';
import '../../messages/chat-timeline/message_bubble.dart' show BubbleColors;
import '../../messages/chat-timeline/bubble_metrics.dart';
import '../data/share_thread_queries.dart';
import '../engine/protocol/share_envelope.dart';
import '../engine/store/share_records.dart';
import '../share_text.dart';
import '../sheets/folder_contents_sheet.dart';
import 'share_bubble_footer.dart';
import 'share_file_row.dart';
import 'share_folder_card.dart';
import 'share_media_grid.dart';
import 'share_open.dart';

bool _isMedia(ShareFileRecord f) =>
    f.mime.startsWith('image/') || f.mime.startsWith('video/');

/// What is inside a bubble: pictures edge to edge on top, then documents, a
/// voice note or a folder, then the text, then the time.
class ShareBubbleContent extends ConsumerWidget {
  const ShareBubbleContent({
    super.key,
    required this.data,
    required this.colors,
    required this.onRetry,
  });

  final ShareBubbleData data;
  final BubbleColors colors;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = data.message;
    final folder = message.kind == ShareKind.folder;
    final voice = message.kind == ShareKind.voice;
    final media = folder || voice
        ? const <ShareFileRecord>[]
        : data.files.where(_isMedia).toList();
    final documents = folder || voice
        ? const <ShareFileRecord>[]
        : data.files.where((f) => !_isMedia(f)).toList();
    final text = message.text;

    void open(ShareFileRecord file) => openShareFile(
      context,
      file,
      data.files,
      missingText: lsText(ref, 'ls_file_missing'),
    );

    const inset = EdgeInsets.symmetric(
      horizontal: BubbleMetrics.horizontalPadding,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (media.isNotEmpty)
          ShareMediaGrid(data: data, media: media, onOpen: open),
        Padding(
          padding: inset.copyWith(
            top: BubbleMetrics.topPadding,
            bottom: BubbleMetrics.bottomPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (folder)
                ShareFolderCard(
                  data: data,
                  colors: colors,
                  onTap: () => showFolderContentsSheet(context, data),
                ),
              if (voice && data.files.isNotEmpty) _voice(ref, data.files.first),
              for (final file in documents)
                ShareFileRow(
                  message: message,
                  file: file,
                  colors: colors,
                  onTap: () => open(file),
                ),
              if (text != null && text.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(
                    top: data.files.isEmpty ? 0 : 4,
                    bottom: 2,
                  ),
                  child: SelectableText(
                    text,
                    style: TextStyle(
                      fontSize: BubbleMetrics.bodyTextSize,
                      height: 1.3,
                      color: colors.foreground,
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                widthFactor: 1,
                child: ShareBubbleFooter(
                  message: message,
                  colors: colors,
                  onRetry: onRetry,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _voice(WidgetRef ref, ShareFileRecord file) {
    if (!file.done && !data.message.fromMe) {
      return ShareFileRow(
        message: data.message,
        file: file,
        colors: colors,
        onTap: () {},
      );
    }
    return SizedBox(
      width: 230,
      child: VoiceUrlPlayer(
        source: AudioSourceRef.file(file.localPath),
        fileName: file.name,
        flat: true,
        waveSeed: file.id,
      ),
    );
  }
}
