import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_wallpaper_photos.dart';

/// "Your photos": every photo set as a wallpaper on this phone, newest first.
/// Tap picks it again; long press removes it from the list.
class ChatWallpaperPhotoGrid extends ConsumerWidget {
  const ChatWallpaperPhotoGrid({
    super.key,
    required this.onSelect,
    this.selectedPath,
  });

  final ValueChanged<String> onSelect;
  final String? selectedPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(chatWallpaperPhotosProvider).valueOrNull ?? [];
    if (photos.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // Tiles are small; decoding a 12 MP photo at full size for each one is
    // what makes a grid of them stutter.
    final cacheWidth = (120 * MediaQuery.devicePixelRatioOf(context)).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 10),
          child: Text('Your photos', style: theme.textTheme.titleSmall),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.72,
          ),
          itemCount: photos.length,
          itemBuilder: (_, index) {
            final path = photos[index];
            final selected = path == selectedPath;
            return GestureDetector(
              onTap: () => onSelect(path),
              onLongPress: () => _confirmRemove(context, ref, path),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(path),
                      fit: BoxFit.cover,
                      cacheWidth: cacheWidth,
                      errorBuilder: (_, _, _) =>
                          ColoredBox(color: colors.surfaceContainerHigh),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? colors.primary
                            : colors.outlineVariant,
                        width: selected ? 3 : 1,
                      ),
                    ),
                    child: selected
                        ? Center(
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: colors.primary,
                              size: 22,
                              shadows: const [
                                Shadow(blurRadius: 6, color: Colors.black54),
                              ],
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    String path,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Remove this photo?'),
        content: const Text(
          'It leaves this list. A chat already using it keeps it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(chatWallpaperPhotosProvider.notifier).remove(path);
    }
  }
}
