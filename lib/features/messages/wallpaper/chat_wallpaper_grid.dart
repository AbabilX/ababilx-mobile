import 'package:flutter/material.dart';

import 'chat_wallpaper.dart';
import 'chat_wallpaper_background.dart';

/// The swatch grid of built-in wallpapers.
class ChatWallpaperGrid extends StatelessWidget {
  const ChatWallpaperGrid({
    super.key,
    required this.onSelect,
    this.selectedPresetId,
  });

  final ValueChanged<ChatWallpaperPreset> onSelect;
  final String? selectedPresetId;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.72,
      ),
      itemCount: chatWallpaperPresets.length,
      itemBuilder: (_, index) {
        final preset = chatWallpaperPresets[index];
        final selected = preset.id == selectedPresetId;
        // Fill and border are separate layers: the fill has to be clipped to
        // the rounded corners for a painting to sit inside them, and a border
        // drawn under that clip would lose its own outer edge.
        return GestureDetector(
          onTap: () => onSelect(preset),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ChatWallpaperPresetPaint(id: preset.id),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? colors.primary : colors.outlineVariant,
                    width: selected ? 3 : 1,
                  ),
                ),
                child: selected
                    ? Center(
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: colors.primary,
                          size: 22,
                          // A tick in the accent colour vanished into the
                          // paintings; the shadow is what keeps it readable on
                          // both a flat swatch and a photo.
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
    );
  }
}
