import 'package:flutter/material.dart';

import 'chat_wallpaper.dart';

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
        return GestureDetector(
          onTap: () => onSelect(preset),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: preset.gradient,
              color: preset.gradient == null ? preset.solid : null,
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
                    ),
                  )
                : const SizedBox.expand(),
          ),
        );
      },
    );
  }
}
