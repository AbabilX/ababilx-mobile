import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../native/ghost_blobs.dart';
import '../providers/ghost_state.dart';
import '../providers/ghost_temp_files.dart';
import '../widgets/ghost_labels.dart';
import 'ghost_viewer_guard.dart';

Future<void> showGhostVideo(BuildContext context, GhostItem item) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => GhostVideoViewer(item: item),
      ),
    );

/// A view-only Ghost video, played in-app.
///
/// On Android the player reads the memory blob through `GhostBlobProvider`'s
/// seekable descriptor, so nothing is written. Elsewhere it plays the ghost
/// temp file — the same fallback opening in another app already used, purged
/// on the burn and at every start.
class GhostVideoViewer extends ConsumerStatefulWidget {
  const GhostVideoViewer({super.key, required this.item});

  final GhostItem item;

  @override
  ConsumerState<GhostVideoViewer> createState() => _GhostVideoViewerState();
}

class _GhostVideoViewerState extends ConsumerState<GhostVideoViewer> {
  VideoPlayerController? _video;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final item = widget.item;
    final Uint8List bytes = item.bytes!;
    final name = item.fileName ?? 'video';
    try {
      final uri = await GhostBlobs.put(
        name,
        item.mime ?? 'video/mp4',
        bytes,
        key: item.id,
      );
      final controller = uri != null
          ? VideoPlayerController.contentUri(Uri.parse(uri))
          : VideoPlayerController.file(
              File(await GhostTempFiles.writeForOpen(name, bytes)),
            );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.play();
      setState(() => _video = controller);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  void _toggle() {
    final video = _video;
    if (video == null) return;
    video.value.isPlaying ? video.pause() : video.play();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final item = watchGhostViewerItem(context, ref, widget.item.id);
    final video = _video;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          item?.fileName ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: item == null
          ? const SizedBox.expand()
          : _failed
          ? Center(
              child: Text(
                ghostText(ref, 'ghost_err_cannot_show'),
                style: const TextStyle(color: Colors.white70),
              ),
            )
          : video == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _toggle,
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: video.value.aspectRatio,
                          child: VideoPlayer(video),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: VideoProgressIndicator(video, allowScrubbing: true),
                  ),
                ],
              ),
            ),
    );
  }
}
