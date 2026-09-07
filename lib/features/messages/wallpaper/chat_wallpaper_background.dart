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
    final surface = Theme.of(context).colorScheme.surface;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final dim = wallpaper.dimInDark && dark;
    final opacity = wallpaper.drawOpacity;

    return Stack(
      fit: StackFit.expand,
      children: [
        // The ground a partly transparent wallpaper fades into. Without it the
        // chat would show through to whatever happens to be behind the stack,
        // so lowering opacity would reveal the scaffold rather than tint the
        // wallpaper — a different picture on every screen it is used on.
        ColoredBox(color: surface),
        switch (wallpaper.kind) {
          ChatWallpaperKind.photo => Image.file(
            File(wallpaper.photoPath),
            fit: BoxFit.cover,
            // `Image`'s own opacity multiplies alpha while painting. Wrapping
            // in an `Opacity` widget instead would push a full-screen
            // saveLayer onto every frame of every chat.
            opacity: AlwaysStoppedAnimation(opacity),
            errorBuilder: (_, _, _) => ColoredBox(color: surface),
          ),
          ChatWallpaperKind.preset => ChatWallpaperPresetPaint(
            id: wallpaper.presetId,
            opacity: opacity,
          ),
          ChatWallpaperKind.none => const SizedBox.shrink(),
        },
        if (dim) ColoredBox(color: Colors.black.withValues(alpha: 0.4)),
      ],
    );
  }
}

/// Paints one preset, filling whatever box it is given.
///
/// Public because the picker grid draws its tiles with it too. A tile that
/// painted a preset by its own rules would drift from the chat it is
/// promising, which is the one thing a swatch has to get right.
class ChatWallpaperPresetPaint extends StatelessWidget {
  const ChatWallpaperPresetPaint({super.key, required this.id, this.opacity = 1});

  final String id;

  /// Left at 1 by the picker grid: a swatch shows what the preset IS, not how
  /// faint this chat currently draws it.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final preset = chatWallpaperPresetById(id);
    if (preset == null) {
      return ColoredBox(color: Theme.of(context).colorScheme.surface);
    }
    final asset = preset.asset;
    if (asset != null) {
      // The solid sits under the image rather than behind a transparent one:
      // it is the ground for the frame or two before the bundle decodes, and
      // for the letterbox on a screen wider than the painting. It has to fade
      // with the image, or turning opacity down would uncover a flat colour
      // instead of the chat surface.
      return ColoredBox(
        color: preset.solid.withValues(alpha: opacity),
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          alignment: chatWallpaperArtAlignment,
          opacity: AlwaysStoppedAnimation(opacity),
        ),
      );
    }
    // Alpha goes on the colours themselves for the same reason it goes on the
    // image: a solid or a gradient can carry it with no extra layer at all.
    final gradient = preset.fadedGradient(opacity);
    if (gradient == null) {
      return ColoredBox(color: preset.solid.withValues(alpha: opacity));
    }
    return DecoratedBox(decoration: BoxDecoration(gradient: gradient));
  }
}
