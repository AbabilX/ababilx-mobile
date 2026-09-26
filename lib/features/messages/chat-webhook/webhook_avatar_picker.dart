import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';
import '../../../shared/widgets/avatar_cache.dart';

/// The feed's bot picture, as a tappable circle.
///
/// A feed has no member whose face could stand in for it, so an unset picture
/// draws the Flock glyph rather than an initial — the same fallback the
/// timeline uses for a webhook message.
class WebhookAvatarPicker extends StatelessWidget {
  const WebhookAvatarPicker({
    super.key,
    this.photo,
    this.url,
    required this.onPick,
    this.onClear,
    this.busy = false,
  });

  /// A picture picked on this device and not uploaded yet. Takes precedence
  /// over [url] so the circle updates the moment it is cropped.
  final Uint8List? photo;
  final String? url;
  final VoidCallback onPick;
  final VoidCallback? onClear;
  final bool busy;

  bool get _hasImage => photo != null || (url ?? '').isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: busy ? null : onPick,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: colors.surfaceContainerHighest,
                foregroundImage: photo != null
                    ? MemoryImage(photo!)
                    : (url ?? '').isNotEmpty
                    ? AvatarCache.provider(url!)
                    : null,
                child: _hasImage
                    ? null
                    : ChatIcon(
                        HugeIcons.strokeRoundedWebhook,
                        color: colors.primary,
                        size: 28,
                      ),
              ),
              CircleAvatar(
                radius: 12,
                backgroundColor: colors.primary,
                child: busy
                    ? SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onPrimary,
                        ),
                      )
                    : Icon(
                        Icons.photo_camera_rounded,
                        size: 13,
                        color: colors.onPrimary,
                      ),
              ),
            ],
          ),
        ),
        if (_hasImage && onClear != null) ...[
          const SizedBox(width: 12),
          TextButton(
            onPressed: busy ? null : onClear,
            child: const Text('Remove'),
          ),
        ],
      ],
    );
  }
}
