import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/app_avatar.dart';

/// A group's banner with its photo sitting on the bottom edge.
///
/// The gradient is not decoration: a banner is whatever picture somebody
/// uploaded, and a pale one would otherwise leave the avatar's white ring
/// invisible against it.
class GroupBannerHeader extends StatelessWidget {
  const GroupBannerHeader({
    super.key,
    required this.url,
    required this.title,
    this.avatarUrl,
    this.bannerHeight = 148,
    this.avatarSize = 96,
    this.extendBehindTop = false,
    this.onBannerTap,
    this.onAvatarTap,
    this.showEditBadges = false,
  });

  final String url;
  final String title;
  final String? avatarUrl;
  final double bannerHeight;
  final double avatarSize;

  /// When true the cover continues under the status bar and the floating
  /// chrome row, so the old AppBar band is part of the picture.
  final bool extendBehindTop;

  /// Settings: tapping the strip changes the cover; tapping the photo
  /// changes the avatar. Details only looks.
  final VoidCallback? onBannerTap;
  final VoidCallback? onAvatarTap;
  final bool showEditBadges;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final topInset = extendBehindTop
        ? MediaQuery.paddingOf(context).top + 48
        : 0.0;
    final coverHeight = bannerHeight + topInset;
    return SizedBox(
      height: coverHeight + avatarSize / 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: GestureDetector(
              onTap: onBannerTap,
              child: SizedBox(
                height: coverHeight,
                child: url.trim().isEmpty
                    ? ColoredBox(color: colors.surfaceContainerHighest)
                    : CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: coverHeight,
                        placeholder: (_, _) =>
                            ColoredBox(color: colors.surfaceContainerHighest),
                        errorWidget: (_, _, _) =>
                            ColoredBox(color: colors.surfaceContainerHighest),
                      ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: IgnorePointer(
              child: SizedBox(
                height: coverHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(
                          alpha: extendBehindTop ? 0.42 : 0,
                        ),
                        Colors.black.withValues(alpha: 0.35),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (showEditBadges)
            Positioned(
              right: 16,
              top: coverHeight - 40,
              child: _EditBadge(onTap: onBannerTap),
            ),
          Positioned(
            left: 0,
            right: 0,
            top: coverHeight - avatarSize / 2,
            child: Center(
              child: GestureDetector(
                key: onAvatarTap == null
                    ? null
                    : const ValueKey('header-avatar-preview'),
                onTap: onAvatarTap,
                child: Semantics(
                  button: onAvatarTap != null,
                  label: onAvatarTap != null ? 'View photo' : null,
                  excludeSemantics: onAvatarTap != null,
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
                            size: avatarSize,
                            url: avatarUrl,
                            name: title,
                          ),
                        ),
                      ),
                      if (showEditBadges)
                        const Positioned(
                          right: 2,
                          bottom: 2,
                          child: _EditBadge(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditBadge extends StatelessWidget {
  const _EditBadge({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final badge = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: colors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: colors.surface, width: 2),
      ),
      child: Icon(
        Icons.photo_camera_rounded,
        size: 14,
        color: colors.onPrimary,
      ),
    );
    if (onTap == null) return badge;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: badge,
      ),
    );
  }
}
