import 'package:flutter/material.dart';

import '../../../shared/widgets/app_bar_back_button.dart';
import 'chat_wallpaper.dart';
import 'chat_wallpaper_background.dart';

/// Opens [wallpaper] on its own screen behind a sample conversation and
/// answers true only when the user presses Save.
///
/// Signal's flow: a tile is too small to judge a picture by, so choosing one
/// shows it the size of a real chat first. Cancel or back keeps the old one.
Future<bool> showChatWallpaperFullPreview(
  BuildContext context,
  ChatWallpaper wallpaper,
) async {
  final ok = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => _FullPreview(wallpaper: wallpaper)),
  );
  return ok ?? false;
}

class _FullPreview extends StatelessWidget {
  const _FullPreview({required this.wallpaper});

  final ChatWallpaper wallpaper;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: const Text('Preview'),
        backgroundColor: colors.surface.withValues(alpha: 0.85),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          ChatWallpaperPaint(wallpaper: wallpaper),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                children: [
                  const Spacer(),
                  _Bubble(text: 'How does this look?', outgoing: false),
                  const SizedBox(height: 8),
                  _Bubble(text: 'Looks good to me', outgoing: true),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: colors.surface,
                          ),
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.outgoing});

  final String text;
  final bool outgoing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: colors.onSurface),
          ),
        ),
      ),
    );
  }
}
