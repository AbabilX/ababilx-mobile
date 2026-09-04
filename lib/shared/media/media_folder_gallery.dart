import 'package:flutter/material.dart';

import 'device_gallery.dart';
import 'media_grid_tile.dart';
import 'media_thumbnail.dart';

/// Signal-style album gallery: folders first, then photos in the chosen album.
///
/// Used by chat wallpaper — not the composer Recent sheet. Returns the tapped
/// [DeviceMediaItem], or null when the user backs out. Images only.
Future<DeviceMediaItem?> showMediaFolderGallery(BuildContext context) async {
  if (!await DeviceGallery.requestAccess()) return null;
  if (!context.mounted) return null;
  return Navigator.of(context).push<DeviceMediaItem>(
    MaterialPageRoute(
      builder: (_) => const _FolderListScreen(),
      fullscreenDialog: true,
    ),
  );
}

class _FolderListScreen extends StatefulWidget {
  const _FolderListScreen();

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
      MaterialPageRoute(
        builder: (_) => _BucketGridScreen(folder: folder),
      ),
    );
    if (item != null && mounted) Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final folders = _folders;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a photo'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
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

class _BucketGridScreen extends StatefulWidget {
  const _BucketGridScreen({required this.folder});

  final DeviceMediaFolder folder;

  @override
  State<_BucketGridScreen> createState() => _BucketGridScreenState();
}

class _BucketGridScreenState extends State<_BucketGridScreen> {
  static const int _pageSize = 60;

  final List<DeviceMediaItem> _items = [];
  final ScrollController _scroll = ScrollController();
  bool _loading = false;
  bool _exhausted = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadMore();
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _exhausted) return;
    setState(() => _loading = true);
    final page = await DeviceGallery.page(
      offset: _items.length,
      limit: _pageSize,
      kind: 'image',
      bucketId: widget.folder.bucketId,
    );
    if (!mounted) return;
    setState(() {
      _items.addAll(page);
      _loading = false;
      _exhausted = page.length < _pageSize;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folder.title),
      ),
      body: _items.isEmpty && _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? Center(
              child: Text(
                'Nothing in this album',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            )
          : GridView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 3,
                crossAxisSpacing: 3,
              ),
              itemCount: _items.length,
              itemBuilder: (_, index) {
                final item = _items[index];
                return MediaGridTile(
                  item: item,
                  showSelectionChrome: false,
                  onTap: () => Navigator.pop(context, item),
                );
              },
            ),
    );
  }
}
