import 'package:flutter/material.dart';

import 'chat_wallpaper.dart';

/// How strongly the wallpaper is drawn, from [chatWallpaperMinOpacity] to 1.
///
/// Dragging reports continuously so the preview above tracks the thumb, but
/// only [onSettled] writes: a slider that saved on every frame would put a few
/// hundred SharedPreferences writes behind one gesture.
class ChatWallpaperOpacitySlider extends StatelessWidget {
  const ChatWallpaperOpacitySlider({
    super.key,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.onSettled,
  });

  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onSettled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (value * 100).round();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.opacity_rounded,
                size: 22,
                color: enabled
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.disabledColor,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Wallpaper opacity',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: enabled ? null : theme.disabledColor,
                  ),
                ),
              ),
              Text(
                '$percent%',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: enabled
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.disabledColor,
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(chatWallpaperMinOpacity, 1),
            min: chatWallpaperMinOpacity,
            max: 1,
            // 5% steps. A continuous slider cannot be landed on a round number
            // with a thumb, and nobody wants 63%.
            divisions: ((1 - chatWallpaperMinOpacity) * 20).round(),
            label: '$percent%',
            onChanged: enabled ? onChanged : null,
            onChangeEnd: enabled ? onSettled : null,
          ),
          Text(
            'Fades the background into the chat so text stays easy to read.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
