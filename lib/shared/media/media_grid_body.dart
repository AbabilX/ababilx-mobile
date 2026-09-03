import 'package:flutter/material.dart';

import 'device_gallery.dart';
import 'media_grid_sheet.dart';
import 'media_grid_tile.dart';

/// The scrolling body of the media sheet: header row, then a paged grid.
class MediaGridBody extends StatefulWidget {
  const MediaGridBody({
    super.key,
    required this.scrollController,
    required this.allowMultiple,
    required this.allowVideo,
    required this.allowFiles,
    required this.maxSelection,
    required this.title,
  });

  final ScrollController scrollController;
  final bool allowMultiple;
  final bool allowVideo;
  final bool allowFiles;
  final int maxSelection;
  final String title;

  @override
  State<MediaGridBody> createState() => _MediaGridBodyState();
}

class _MediaGridBodyState extends State<MediaGridBody> {
  static const int _pageSize = 60;

  final List<DeviceMediaItem> _items = [];
  final List<DeviceMediaItem> _selected = [];
  bool _loading = false;
  bool _exhausted = false;

  @override
  void initState() {
    super.initState();
    _loadMore();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!widget.scrollController.hasClients) return;
    final position = widget.scrollController.position;
    if (position.pixels > position.maxScrollExtent - 600) _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || _exhausted) return;
    setState(() => _loading = true);
    final page = await DeviceGallery.page(
      offset: _items.length,
      limit: _pageSize,
      kind: widget.allowVideo ? 'all' : 'image',
    );
    if (!mounted) return;
    setState(() {
      _items.addAll(page);
      _loading = false;
      _exhausted = page.length < _pageSize;
    });
  }

  void _toggle(DeviceMediaItem item) {
    if (!widget.allowMultiple) {
      Navigator.pop(context, MediaSheetResult(MediaSheetAction.picked, [item]));
      return;
    }
    setState(() {
      if (_selected.remove(item)) return;
      if (_selected.length >= widget.maxSelection) return;
      _selected.add(item);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Text(
                widget.title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Camera',
                icon: const Icon(Icons.photo_camera_outlined),
                onPressed: () => Navigator.pop(
                  context,
                  const MediaSheetResult(MediaSheetAction.camera),
                ),
              ),
              if (widget.allowFiles)
                IconButton(
                  tooltip: 'Files',
                  icon: const Icon(Icons.folder_outlined),
                  onPressed: () => Navigator.pop(
                    context,
                    const MediaSheetResult(MediaSheetAction.files),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _items.isEmpty && !_loading
              ? Center(
                  child: Text(
                    'Nothing in your library yet',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                )
              : GridView.builder(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 3,
                    crossAxisSpacing: 3,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (_, index) {
                    final item = _items[index];
                    final position = _selected.indexOf(item);
                    return MediaGridTile(
                      item: item,
                      selectionIndex: position < 0 ? null : position + 1,
                      onTap: () => _toggle(item),
                    );
                  },
                ),
        ),
        if (_selected.isNotEmpty)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(
                  context,
                  MediaSheetResult(MediaSheetAction.picked, List.of(_selected)),
                ),
                icon: const Icon(Icons.check_rounded),
                label: Text('Add ${_selected.length}'),
              ),
            ),
          ),
      ],
    );
  }
}
