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
  });

  final String url;
  final String title;
  final String? avatarUrl;
  final double bannerHeight;
  final double avatarSize;

  /// When true the cover continues under the status bar and the floating
  /// chrome row, so the old AppBar band is part of the picture.
  final bool extendBehindTop;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final topInset = extendBehindTop ? MediaQuery.paddingOf(context).top + 48 : 0;
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
            child: SizedBox(
              height: coverHeight,
              // CachedNetworkImage rather than a DecorationImage over a raw
              // NetworkImage: the banner is the largest image in the app, and a
              // raw one is re-fetched on every cold open of this screen and
              // throws an uncatchable image exception on a 404 instead of
              // falling back to the plain surface colour.
              child: CachedNetworkImage(
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
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SizedBox(
              height: coverHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: extendBehindTop ? 0.42 : 0),
                      Colors.black.withValues(alpha: 0.35),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: coverHeight - avatarSize / 2,
            child: Center(
              child: Container(
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
            ),
          ),
        ],
      ),
    );
  }
}
