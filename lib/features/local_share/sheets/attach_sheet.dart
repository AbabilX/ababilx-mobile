import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';
import '../local_share_actions.dart';
import '../providers/share_folder_picker.dart';
import '../share_picking.dart';
import '../share_text.dart';

/// What the user chose to attach. [folderName] is set when it is a folder.
class ShareAttachment {
  const ShareAttachment(this.picks, {this.folderName});

  final List<SharePick> picks;
  final String? folderName;
}

enum _Source { media, files, folder }

/// Photos and videos, files, or a whole folder.
Future<ShareAttachment?> showShareAttachSheet(BuildContext context) async {
  final folders = await ShareFolderPicker.supported();
  if (!context.mounted) return null;
  final source = await showModalBottomSheet<_Source>(
    context: context,
    showDragHandle: true,
    builder: (_) => Consumer(
      builder: (context, ref, _) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _row(
              context,
              ref,
              _Source.media,
              'ls_attach_media',
              HugeIcons.strokeRoundedImage01,
            ),
            _row(
              context,
              ref,
              _Source.files,
              'ls_attach_files',
              HugeIcons.strokeRoundedFile01,
            ),
            if (folders)
              _row(
                context,
                ref,
                _Source.folder,
                'ls_attach_folder',
                HugeIcons.strokeRoundedFolder01,
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
  if (source == null || !context.mounted) return null;
  switch (source) {
    case _Source.media:
      return ShareAttachment(await pickShareMedia(context));
    case _Source.files:
      return ShareAttachment(await pickShareFiles());
    case _Source.folder:
      final folder = await ShareFolderPicker.pick();
      return folder == null
          ? null
          : ShareAttachment(folder.picks, folderName: folder.name);
  }
}

Widget _row(
  BuildContext context,
  WidgetRef ref,
  _Source source,
  String key,
  List<List<dynamic>> icon,
) {
  return ListTile(
    leading: ChatIcon(icon),
    title: Text(lsText(ref, key)),
    onTap: () => Navigator.pop(context, source),
  );
}
