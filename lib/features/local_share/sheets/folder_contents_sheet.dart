import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../messages/chat-timeline/message_bubble.dart' show BubbleColors;
import '../bubbles/share_file_row.dart';
import '../bubbles/share_open.dart';
import '../data/share_thread_queries.dart';
import '../share_text.dart';

/// The files of a sent or received folder, by their path inside it.
Future<void> showFolderContentsSheet(
  BuildContext context,
  ShareBubbleData data,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (context, controller) => Consumer(
        builder: (context, ref, _) {
          final colors = BubbleColors.of(
            Theme.of(context).colorScheme,
            hasWallpaper: false,
          );
          return ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Text(
                data.message.folderName ?? '',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final file in data.files)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShareFileRow(
                        message: data.message,
                        file: file,
                        colors: colors,
                        onTap: () => openShareFile(
                          context,
                          file,
                          data.files,
                          missingText: lsText(ref, 'ls_file_missing'),
                        ),
                      ),
                      if (file.relPath != null && file.relPath != file.name)
                        Padding(
                          padding: const EdgeInsets.only(left: 50),
                          child: Text(
                            file.relPath!,
                            style: TextStyle(fontSize: 11, color: colors.muted),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}
