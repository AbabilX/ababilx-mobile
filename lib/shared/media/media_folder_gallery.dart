import 'package:flutter/material.dart';

import 'device_gallery.dart';
import 'media_bucket_grid.dart';
import 'media_thumbnail.dart';

/// How the gallery was left: with a photo, or with a request for the camera.
enum MediaGalleryAction { picked, camera }

@immutable
class MediaGalleryResult {
  const MediaGalleryResult(this.action, [this.item]);

  final MediaGalleryAction action;

  /// The chosen photo. Null for [MediaGalleryAction.camera].
  final DeviceMediaItem? item;
}

/// Signal-style album gallery: folders first, then photos in the chosen album.
///
/// This is the picker for anything that takes ONE deliberate photo — a profile
/// picture, a group photo, a chat wallpaper. Those are chosen from the whole
/// library, and often not from this week, so a flat "Recent" strip is the wrong
/// shape: it shows the last screenful and offers no way to reach an album. The
/// composer's Recent sheet stays what it is, because sharing what you just shot
/// is a different job.
///
/// Returns null when the user backs out, or immediately when the library is
/// unreadable — no permission, or a platform without the MediaStore channel.
/// Callers must treat that second case as "fall through to the system picker",
/// not as a cancel; [DeviceGallery.requestAccess] is public so they can tell
/// the two apart before opening this.
///
/// Images only. [allowCamera] adds a shutter button to the app bar, for the
/// flows where taking the photo now is as likely as finding one.
Future<MediaGalleryResult?> showMediaFolderGallery(
  BuildContext context, {
  String title = 'Choose a photo',
  bool allowCamera = false,
}) async {
  if (!await DeviceGallery.requestAccess()) return null;
  if (!context.mounted) return null;
  return Navigator.of(context).push<MediaGalleryResult>(
    MaterialPageRoute(
      builder: (_) => _FolderListScreen(title: title, allowCamera: allowCamera),
      fullscreenDialog: true,
    ),
  );
}

class _FolderListScreen extends StatefulWidget {
  const _FolderListScreen({required this.title, required this.allowCamera});

  final String title;
  final bool allowCamera;

  @override
  State<_FolderListScreen> createState() => _FolderListScreenState();
}

class _FolderListScreenState extends State<_FolderListScreen> {
  List<DeviceMediaFolder>? _folders;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final folders = await DeviceGallery.folders(kind: 'image');
    if (!mounted) return;
    setState(() {
      _folders = folders;
      _loading = false;
    });
  }

  Future<void> _openFolder(DeviceMediaFolder folder) async {
    final item = await Navigator.of(context).push<DeviceMediaItem>(
      MaterialPageRoute(builder: (_) => MediaBucketGridScreen(folder: folder)),
    );
    if (item != null && mounted) {
      Navigator.pop(
        context,
        MediaGalleryResult(MediaGalleryAction.picked, item),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final folders = _folders;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (widget.allowCamera)
            IconButton(
              tooltip: 'Take a photo',
              icon: const Icon(Icons.photo_camera_outlined),
              onPressed: () => Navigator.pop(
                context,
                const MediaGalleryResult(MediaGalleryAction.camera),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : folders == null || folders.isEmpty
          ? Center(
              child: Text(
                'Nothing in your library yet',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.92,
              ),
              itemCount: folders.length,
              itemBuilder: (_, index) {
                final folder = folders[index];
                return _FolderTile(
                  folder: folder,
                  onTap: () => _openFolder(folder),
                );
              },
            ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({required this.folder, required this.onTap});

  final DeviceMediaFolder folder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: folder.thumbnailUri.isEmpty
                  ? ColoredBox(color: colors.surfaceContainerHighest)
                  : MediaThumbnail(item: folder.thumbnailItem),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            folder.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            '${folder.count}',
            style: textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
