import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';
import 'ram_media_cache.dart';

Future<void> showRamPhotos(
  BuildContext context, {
  required List<String> urls,
  int initial = 0,
}) => Navigator.of(context, rootNavigator: true).push(
  MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => RamPhotoViewer(urls: urls, initial: initial),
  ),
);

/// A locked chat's photos, full screen, from memory. No Save and no Share —
/// either would write the picture somewhere the lock does not reach.
class RamPhotoViewer extends StatefulWidget {
  const RamPhotoViewer({super.key, required this.urls, this.initial = 0});

  final List<String> urls;
  final int initial;

  @override
  State<RamPhotoViewer> createState() => _RamPhotoViewerState();
}

class _RamPhotoViewerState extends State<RamPhotoViewer> {
  late final _pages = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final count = widget.urls.length;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const ChatIcon(HugeIcons.strokeRoundedCancel01),
        ),
        title: count > 1 ? Text('${_index + 1} / $count') : null,
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: count,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) => FutureBuilder<Uint8List>(
          future: RamMediaCache.fetch(widget.urls[i]),
          builder: (context, snap) {
            final bytes = snap.data;
            if (bytes == null) {
              return Center(
                child: snap.hasError
                    ? ChatIcon(
                        HugeIcons.strokeRoundedImageNotFound01,
                        color: colors.onSurfaceVariant,
                        size: 32,
                      )
                    : const CircularProgressIndicator(),
              );
            }
            return InteractiveViewer(
              maxScale: 5,
              child: Center(child: Image.memory(bytes, gaplessPlayback: true)),
            );
          },
        ),
      ),
    );
  }
}
