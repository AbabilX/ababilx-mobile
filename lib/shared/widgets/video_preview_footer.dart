import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'image_preview_chrome.dart';
import 'image_preview_dock.dart';
import 'video_fullscreen_controls.dart';

/// Caption + scrubber on the dark strip; Save / Rotate / Mute / Share capsule.
class VideoPreviewFooter extends StatelessWidget {
  const VideoPreviewFooter({
    super.key,
    required this.controller,
    required this.onInteract,
    required this.fileName,
    this.localPath,
    this.remoteUrl,
    this.caption,
    required this.muted,
    required this.onMute,
    required this.onRotate,
    required this.onTogglePlay,
  });

  final VideoPlayerController controller;
  final VoidCallback onInteract;
  final String fileName;
  final String? localPath;
  final String? remoteUrl;
  final String? caption;
  final bool muted;
  final VoidCallback onMute;

  /// View-only quarter turn. Save / Share still write the original file.
  final VoidCallback onRotate;
  final VoidCallback onTogglePlay;

  @override
  Widget build(BuildContext context) {
    final captionText = caption?.trim();
    final hasCaption = captionText != null && captionText.isNotEmpty;
    final hasDock =
        fileName.trim().isNotEmpty &&
        ImagePreviewDock.hasSource(localPath: localPath, remoteUrl: remoteUrl);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: ImagePreviewChrome.bar,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasCaption) _Caption(text: captionText),
              VideoFullscreenControls(
                controller: controller,
                onInteract: onInteract,
                onTogglePlay: onTogglePlay,
              ),
            ],
          ),
        ),
        if (hasDock)
          ImagePreviewDockSlot(
            child: ImagePreviewDock(
              fileName: fileName,
              localPath: localPath,
              remoteUrl: remoteUrl,
              muted: muted,
              onMute: onMute,
              onRotate: onRotate,
            ),
          )
        else
          const SafeArea(top: false, child: SizedBox(height: 8)),
      ],
    );
  }
}

/// Same expand-on-tap as the photo caption — kept here so shared video
/// does not import the chat feature tree.
class _Caption extends StatefulWidget {
  const _Caption({required this.text});

  final String text;

  @override
  State<_Caption> createState() => _CaptionState();
}

class _CaptionState extends State<_Caption> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _open = !_open),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          widget.text,
          maxLines: _open ? null : 2,
          overflow: _open ? TextOverflow.visible : TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
