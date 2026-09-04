import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../data/models/chat_models.dart';

/// The wide strip. Tapping anywhere on it starts the banner flow, so the
/// badge is a label rather than the only target.
class GroupBannerSurface extends StatelessWidget {
  const GroupBannerSurface({
    super.key,
    required this.url,
    required this.height,
    required this.colors,
    required this.onTap,
    this.busy = false,
  });

  final String? url;
  final double height;
  final ColorScheme colors;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final empty = (url ?? '').isEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: colors.surfaceContainerHighest),
              // Cached, like every other remote image in the app: this is the
              // largest picture the feature has, and a raw NetworkImage would
              // re-fetch it on every open and throw on a 404 rather than
              // falling back to the plain surface.
              if (!empty)
                CachedNetworkImage(
                  imageUrl: url!,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const SizedBox.shrink(),
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _EditBadge(
                    colors: colors,
                    icon: Icons.photo_size_select_actual_rounded,
                    label: busy
                        ? 'Uploading…'
                        : empty
                        ? 'Add banner'
                        : 'Change banner',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The circle that overlaps the banner, with a camera badge on it.
class GroupPhotoSurface extends StatelessWidget {
  const GroupPhotoSurface({
    super.key,
    required this.conversation,
    required this.size,
    required this.colors,
    required this.onTap,
    this.busy = false,
  });

  final ChatConversation conversation;
  final double size;
  final ColorScheme colors;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.surface,
          ),
          child: ClipOval(
            child: AppAvatar(
              size: size,
              url: conversation.avatarUrl,
              name: conversation.name ?? '',
            ),
          ),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: CircleAvatar(
            radius: 14,
            backgroundColor: colors.primary,
            child: busy
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.onPrimary,
                    ),
                  )
                : Icon(
                    Icons.photo_camera_rounded,
                    size: 15,
                    color: colors.onPrimary,
                  ),
          ),
        ),
      ],
    ),
  );
}

class _EditBadge extends StatelessWidget {
  const _EditBadge({
    required this.colors,
    required this.icon,
    required this.label,
  });

  final ColorScheme colors;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: colors.surface.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colors.onSurface),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
      ],
    ),
  );
}
