import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Profile and group pictures, kept in the app's own cache directory (never
/// the gallery) apart from every other network image.
///
/// The default manager holds 200 objects for the whole app, so a scroll
/// through the wall or a few shared photos evicted the chat list's faces and
/// the next launch fetched them again. Avatars are small and seen on every
/// launch; they get their own store, sized for a long contact list.
class AvatarCache {
  AvatarCache._();

  static final CacheManager instance = CacheManager(
    Config(
      'avatars_v1',
      stalePeriod: const Duration(days: 365),
      maxNrOfCacheObjects: 2000,
    ),
  );

  /// For a `CircleAvatar.backgroundImage` or any other place that takes an
  /// [ImageProvider] instead of [AppAvatar].
  static ImageProvider provider(String url) =>
      CachedNetworkImageProvider(url, cacheManager: instance);
}
