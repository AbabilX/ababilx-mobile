import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';
import '../data/shared_payload.dart';
import '../providers/share_intake_provider.dart';

/// What is about to be sent, across the top of the share screen.
///
/// Images and videos get a real thumbnail off disk — the file is already in
/// our cache, so there is nothing to download — and everything else gets a
/// named file chip.
class SharePayloadPreview extends StatelessWidget {
  const SharePayloadPreview({super.key, required this.payload});

  final SharedPayload payload;

  static const double _size = 72;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (!payload.hasFiles) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Text(
          payload.text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _size,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: payload.files.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) =>
                _Thumb(file: payload.files[i], size: _size - 8),
          ),
        ),
        if (payload.oversizedCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              '${payload.oversizedCount} file'
              '${payload.oversizedCount == 1 ? '' : 's'} over 200 MB '
              '${payload.oversizedCount == 1 ? 'is' : 'are'} too large and '
              'will not be sent.',
              style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
            ),
          ),
      ],
    );
  }
}

class _Thumb extends ConsumerWidget {
  const _Thumb({required this.file, required this.size});

  final SharedFile file;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dimmed = file.isTooLarge;

    return Opacity(
      opacity: dimmed ? 0.4 : 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: size,
          height: size,
          child: file.hasPreview
              ? _NativeThumb(file: file, size: size)
              : _FileTile(file: file),
        ),
      ),
    );
  }
}

/// Preview decoded natively from the original content URI.
///
/// Nothing is copied to draw a 72dp tile: `ShareIntakeBridge.thumbnail`
/// downsamples an image while decoding, and pulls a single frame for a video.
class _NativeThumb extends ConsumerStatefulWidget {
  const _NativeThumb({required this.file, required this.size});

  final SharedFile file;
  final double size;

  @override
  ConsumerState<_NativeThumb> createState() => _NativeThumbState();
}

class _NativeThumbState extends ConsumerState<_NativeThumb> {
  Uint8List? _bytes;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final bytes = await ref
        .read(shareIntakeChannelProvider)
        .thumbnail(widget.file.uri, maxPx: 256);
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _done = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bytes = _bytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _FileTile(file: widget.file),
      );
    }
    // No preview available (or still decoding): a video icon still tells the
    // user what they picked, which a blank tile does not.
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: _done && widget.file.isVideo
            ? ChatIcon(
                HugeIcons.strokeRoundedVideo01,
                size: 26,
                color: colors.onSurfaceVariant,
              )
            : _done
            ? ChatIcon(
                HugeIcons.strokeRoundedImage01,
                size: 26,
                color: colors.onSurfaceVariant,
              )
            : SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({required this.file});

  final SharedFile file;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Tooltip(
        message: file.fileName,
        child: Center(
          child: ChatIcon(
            HugeIcons.strokeRoundedFile01,
            size: 26,
            color: colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
