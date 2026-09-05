import 'package:flutter/material.dart';

import 'device_gallery.dart';
import 'media_grid_tile.dart';

/// The photos inside one album, paged as the user scrolls.
///
/// Pops the tapped [DeviceMediaItem] back to the folder list, which pops it
/// again to whoever opened the gallery.
class MediaBucketGridScreen extends StatefulWidget {
  const MediaBucketGridScreen({super.key, required this.folder});

  final DeviceMediaFolder folder;

  @override
  State<MediaBucketGridScreen> createState() => _MediaBucketGridScreenState();
}

class _MediaBucketGridScreenState extends State<MediaBucketGridScreen> {
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
      appBar: AppBar(title: Text(widget.folder.title)),
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
