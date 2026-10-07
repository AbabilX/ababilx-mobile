import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../media/media_save_lock.dart';
import '../media/save_to_phone.dart';
import '../media/save_to_phone_action.dart';
import 'preview_icon.dart';
import 'app_toast.dart';

/// Signal's media-viewer actions, in Signal's two places.
///
/// Save lives in the toolbar overflow so it never competes with the media for
/// space; Share is a button on the bottom bar, where a thumb reaches it. Both
/// need bytes on disk — a viewer showing a remote URL passes a null path and
/// gets no affordance rather than a button that fails.
enum MediaPreviewAction { save, share }

class MediaPreviewOverflow extends StatelessWidget {
  const MediaPreviewOverflow({
    super.key,
    required this.localPath,
    required this.fileName,
    this.remoteUrl,
    this.contentType = '',
    this.onDark = true,
  });

  final String? localPath;
  final String fileName;

  /// Set only by viewers that are already rendering from this URL. Chat leaves
  /// it null so its bytes keep coming through the attachment pipeline.
  final String? remoteUrl;
  final String contentType;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final path = localPath;
    final url = remoteUrl;
    final hasSource =
        (path != null && path.isNotEmpty) || (url != null && url.isNotEmpty);
    if (!hasSource) return const SizedBox.shrink();
    final tint = onDark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    return PopupMenuButton<MediaPreviewAction>(
      tooltip: 'More options',
      icon: PreviewIcon(PreviewIcons.more, color: tint),
      onSelected: (action) => runMediaPreviewAction(
        context,
        action,
        localPath: path,
        remoteUrl: url,
        fileName: fileName,
        contentType: contentType,
      ),
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: MediaPreviewAction.save,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: PreviewIcon(PreviewIcons.save),
            title: Text('Save'),
          ),
        ),
        PopupMenuItem(
          value: MediaPreviewAction.share,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: PreviewIcon(PreviewIcons.share),
            title: Text('Share'),
          ),
        ),
      ],
    );
  }
}

Future<void> runMediaPreviewAction(
  BuildContext context,
  MediaPreviewAction action, {
  String? localPath,
  String? remoteUrl,
  required String fileName,
  String contentType = '',
}) async {
  // A private group's content never leaves the app, whatever drew the button.
  if (MediaSaveLock.held) return;
  final path = await resolvePreviewFile(
    localPath: localPath,
    remoteUrl: remoteUrl,
    fileName: fileName,
  );
  if (!context.mounted) return;
  if (path == null) {
    showAppToast(context, 'File is not available', isError: true);
    return;
  }
  switch (action) {
    case MediaPreviewAction.save:
      await saveOneToPhone(
        context,
        localPath: path,
        fileName: fileName,
        contentType: contentType,
      );
    case MediaPreviewAction.share:
      await shareLocalFile(path, fileName: fileName);
  }
}

/// A path the OS can read, whichever half of the viewer had the bytes.
Future<String?> resolvePreviewFile({
  required String? localPath,
  required String? remoteUrl,
  required String fileName,
}) async {
  if (localPath != null && localPath.isNotEmpty) return localPath;
  if (remoteUrl == null || remoteUrl.isEmpty) return null;
  return fetchToTempFile(remoteUrl, fileName);
}

Future<void> shareLocalFile(
  String localPath, {
  required String fileName,
}) async {
  if (localPath.isEmpty) return;
  await SharePlus.instance.share(
    ShareParams(files: [XFile(localPath, name: fileName)]),
  );
}

/// The round high-contrast button the fullscreen viewers use for close — the
/// same shape, so Share sits beside it without inventing a second style.
class MediaPreviewCircleButton extends StatelessWidget {
  const MediaPreviewCircleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(
          side: BorderSide(color: Colors.black, width: 1.5),
        ),
        elevation: 4,
        shadowColor: Colors.black54,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: Colors.black, size: 24),
          ),
        ),
      ),
    );
  }
}
