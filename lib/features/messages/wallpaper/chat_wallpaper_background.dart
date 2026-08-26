import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_wallpaper.dart';
import 'chat_wallpaper_provider.dart';

/// Paints a chat's wallpaper behind [child].
///
/// When nothing is set the child is returned untouched, so a chat with no
/// wallpaper costs no extra layer and keeps the theme's own surface colour.
class ChatWallpaperBackground extends ConsumerStatefulWidget {
  const ChatWallpaperBackground({
    super.key,
    required this.conversationId,
    required this.child,
  });

  final String conversationId;
  final Widget child;

  @override
  ConsumerState<ChatWallpaperBackground> createState() =>
      _ChatWallpaperBackgroundState();
}

class _ChatWallpaperBackgroundState
    extends ConsumerState<ChatWallpaperBackground> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(chatWallpaperProvider.notifier)
          .ensureLoaded(widget.conversationId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final wallpaper = ref
        .watch(chatWallpaperProvider)
        .forChat(widget.conversationId);
    if (!wallpaper.isSet) return widget.child;

    return Stack(
      fit: StackFit.expand,
      children: [
        ChatWallpaperPaint(wallpaper: wallpaper),
        widget.child,
      ],
    );
  }
}

/// The wallpaper itself, without the chat on top — also used by the picker's
/// preview tiles so what you choose is exactly what you get.
class ChatWallpaperPaint extends StatelessWidget {
  const ChatWallpaperPaint({super.key, required this.wallpaper});

  final ChatWallpaper wallpaper;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final dim = wallpaper.dimInDark && dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        switch (wallpaper.kind) {
          ChatWallpaperKind.photo => Image.file(
            File(wallpaper.photoPath),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                ColoredBox(color: Theme.of(context).colorScheme.surface),
          ),
          ChatWallpaperKind.preset => _Preset(id: wallpaper.presetId),
          ChatWallpaperKind.none => const SizedBox.shrink(),
        },
        if (dim) ColoredBox(color: Colors.black.withValues(alpha: 0.4)),
      ],
    );
  }
}

class _Preset extends StatelessWidget {
  const _Preset({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final preset = chatWallpaperPresetById(id);
    if (preset == null) {
      return ColoredBox(color: Theme.of(context).colorScheme.surface);
    }
    final gradient = preset.gradient;
    if (gradient == null) return ColoredBox(color: preset.solid);
    return DecoratedBox(decoration: BoxDecoration(gradient: gradient));
  }
}
