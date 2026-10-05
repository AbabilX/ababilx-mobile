import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/media/video_thumbnail.dart';
import '../../messages/chat_icon.dart';
import '../engine/store/share_records.dart';
import 'share_file_progress.dart';

/// A photo or a video inside a bubble, drawn from the file on this device.
///
/// A video shows one cached native frame, never a live player: each player is
/// a hardware decoder out of a small pool, and a thread with a few videos in
/// view would empty it.
class ShareMediaTile extends ConsumerWidget {
  const ShareMediaTile({
    super.key,
    required this.message,
    required this.file,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final ShareMessageRecord message;
  final ShareFileRecord file;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final fraction = shareFileFraction(ref, message, file);
    // An incoming file is only at its final path once every byte is here.
    final ready = file.done || message.fromMe;
    final isVideo = file.mime.startsWith('video/');
    final cache = (width * MediaQuery.devicePixelRatioOf(context)).round();

    Widget picture = ColoredBox(color: colors.surfaceContainerHighest);
    if (ready && !isVideo) {
      picture = Image.file(
        File(file.localPath),
        fit: BoxFit.cover,
        cacheWidth: cache,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _missing(colors),
      );
    } else if (ready) {
      picture = _VideoFrame(path: file.localPath, cacheWidth: cache);
    }

    return GestureDetector(
      onTap: file.done || message.fromMe ? onTap : null,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            picture,
            if (fraction != null)
              Center(child: ShareProgressRing(fraction: fraction))
            else if (isVideo && ready)
              const Center(child: _PlayBadge()),
          ],
        ),
      ),
    );
  }

  Widget _missing(ColorScheme colors) => ColoredBox(
    color: colors.surfaceContainerHighest,
    child: Center(
      child: ChatIcon(
        HugeIcons.strokeRoundedImageNotFound01,
        color: colors.onSurfaceVariant,
      ),
    ),
  );
}

class _VideoFrame extends StatelessWidget {
  const _VideoFrame({required this.path, required this.cacheWidth});

  final String path;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    final ready = VideoThumbnails.peek(path);
    if (ready != null) return _frame(ready);
    return FutureBuilder<VideoThumb?>(
      future: VideoThumbnails.forFile(path),
      builder: (context, snapshot) {
        final thumb = snapshot.data;
        return thumb == null
            ? const ColoredBox(color: Colors.black)
            : _frame(thumb);
      },
    );
  }

  Widget _frame(VideoThumb thumb) => Image.file(
    File(thumb.path),
    fit: BoxFit.cover,
    cacheWidth: cacheWidth,
    gaplessPlayback: true,
  );
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: Color(0x99000000),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const ChatIcon(
        HugeIcons.strokeRoundedPlay,
        size: 22,
        color: Colors.white,
      ),
    );
  }
}
