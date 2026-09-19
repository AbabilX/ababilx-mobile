import 'package:flutter/material.dart';
import 'package:ababilx/shared/widgets/app_bar_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/media/pick_wallpaper_photo.dart';
import 'chat_wallpaper.dart';
import 'chat_wallpaper_grid.dart';
import 'chat_wallpaper_opacity_slider.dart';
import 'chat_wallpaper_preview.dart';
import 'chat_wallpaper_provider.dart';

/// Wallpaper picker, for one chat or for every chat.
///
/// [conversationId] null means the global default. With a conversation the
/// screen also offers "Use the default again", which is the only way to
/// distinguish a chat the user deliberately left plain from one that simply
/// never had an override.
class ChatWallpaperScreen extends ConsumerStatefulWidget {
  const ChatWallpaperScreen({super.key, this.conversationId});

  final String? conversationId;

  @override
  ConsumerState<ChatWallpaperScreen> createState() =>
      _ChatWallpaperScreenState();
}

class _ChatWallpaperScreenState extends ConsumerState<ChatWallpaperScreen> {
  ChatWallpaper? _draft;

  ChatWallpaper _current(ChatWallpaperState state) {
    final id = widget.conversationId;
    return _draft ?? (id == null ? state.global : state.forChat(id));
  }

  Future<void> _apply(ChatWallpaper wallpaper) async {
    setState(() => _draft = wallpaper);
    final notifier = ref.read(chatWallpaperProvider.notifier);
    final id = widget.conversationId;
    if (id == null) {
      await notifier.setGlobal(wallpaper);
    } else {
      await notifier.setForChat(id, wallpaper);
    }
  }

  Future<void> _pickPhoto() async {
    final path = await pickWallpaperPhoto(context);
    if (path == null) return;
    await _apply(_carrying(ChatWallpaper.photo(path)));
  }

  /// Keeps the two adjustments across a change of picture.
  ///
  /// They belong to the chat, not to the image: picking a second wallpaper to
  /// compare it against the first used to snap opacity and dimming back to
  /// their defaults, which made the comparison meaningless.
  ChatWallpaper _carrying(ChatWallpaper next) {
    final current = _current(ref.read(chatWallpaperProvider));
    return next.copyWith(
      dimInDark: current.dimInDark,
      opacity: current.opacity,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatWallpaperProvider);
    final wallpaper = _current(state);
    final perChat = widget.conversationId != null;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: Text(perChat ? 'Chat wallpaper' : 'Chat wallpapers'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          ChatWallpaperPreview(wallpaper: wallpaper),
          const SizedBox(height: 20),
          ChatWallpaperGrid(
            selectedPresetId: wallpaper.kind == ChatWallpaperKind.preset
                ? wallpaper.presetId
                : null,
            onSelect: (preset) =>
                _apply(_carrying(ChatWallpaper.preset(preset.id))),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.image_outlined),
            title: const Text('Choose from photos'),
            onTap: _pickPhoto,
          ),
          ChatWallpaperOpacitySlider(
            value: wallpaper.drawOpacity,
            enabled: wallpaper.isSet,
            // Dragging only redraws; the write waits for the thumb to land.
            onChanged: (value) =>
                setState(() => _draft = wallpaper.copyWith(opacity: value)),
            onSettled: (value) => _apply(wallpaper.copyWith(opacity: value)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: wallpaper.dimInDark,
            title: const Text('Dim wallpaper in dark theme'),
            subtitle: const Text(
              'A background bright enough to read against by day is glaring '
              'at night.',
            ),
            onChanged: wallpaper.isSet
                ? (value) => _apply(wallpaper.copyWith(dimInDark: value))
                : null,
          ),
          const Divider(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.format_color_reset_outlined),
            title: const Text('No wallpaper'),
            onTap: () => _apply(ChatWallpaper.none),
          ),
          if (perChat)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.settings_backup_restore_rounded),
              title: const Text('Use the default again'),
              subtitle: const Text('Follow whatever every other chat uses'),
              onTap: () async {
                await ref
                    .read(chatWallpaperProvider.notifier)
                    .clearForChat(widget.conversationId!);
                if (mounted) setState(() => _draft = null);
              },
            )
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.layers_clear_outlined),
              title: const Text('Reset every chat to this'),
              subtitle: const Text('Clears wallpapers set on single chats'),
              onTap: () =>
                  ref.read(chatWallpaperProvider.notifier).clearAllOverrides(),
            ),
        ],
      ),
    );
  }
}
