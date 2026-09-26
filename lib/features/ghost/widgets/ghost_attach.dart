import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../messages/chat_icon.dart';
import '../providers/ghost_provider.dart';
import 'ghost_labels.dart';
import 'ghost_pick.dart';
import 'ghost_send_preview.dart';

/// Photo, camera or file — the composer's "+".
Future<GhostPickSource?> chooseGhostSource(
  BuildContext context,
  WidgetRef ref,
) {
  return showModalBottomSheet<GhostPickSource>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (src, icon, key) in [
            (
              GhostPickSource.gallery,
              HugeIcons.strokeRoundedImage02,
              'ghost_photo',
            ),
            (
              GhostPickSource.camera,
              HugeIcons.strokeRoundedCamera01,
              'ghost_camera',
            ),
            (GhostPickSource.file, HugeIcons.strokeRoundedFile02, 'ghost_file'),
          ])
            ListTile(
              leading: ChatIcon(icon),
              title: Text(ghostText(ref, key)),
              onTap: () => Navigator.of(sheet).pop(src),
            ),
        ],
      ),
    ),
  );
}

/// Pick, let the sender set the timer / saving, then send over the channel.
Future<void> pickAndSendGhost(
  BuildContext context,
  WidgetRef ref,
  GhostPickSource source,
) async {
  try {
    final picked = await pickForGhost(source);
    if (picked == null || !context.mounted) return;
    final rules = await showGhostSendPreview(context, picked);
    // Backed out, or the chat ended under the preview (which disposes the
    // composer): the picked bytes were only ever in RAM; clear them.
    if (rules == null || !context.mounted) {
      picked.bytes.fillRange(0, picked.bytes.length, 0);
      return;
    }
    await ref
        .read(ghostProvider.notifier)
        .sendFile(picked.name, picked.mime, picked.bytes, rules: rules);
  } on GhostFileTooLarge {
    if (context.mounted) {
      showAppToast(
        context,
        ghostText(ref, 'ghost_err_file_too_large'),
        isError: true,
      );
    }
  } catch (_) {
    if (context.mounted) {
      showAppToast(context, ghostText(ref, 'ghost_err_generic'), isError: true);
    }
  }
}
