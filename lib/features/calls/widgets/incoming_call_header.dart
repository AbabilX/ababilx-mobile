import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../shared/text/display_name.dart';
import '../../../shared/widgets/avatar_cache.dart';
import 'call_top_bar.dart' show callTextShadow;

/// The top half of Signal's `IncomingCallScreen`, top to bottom: which kind of
/// call this is, an 80dp avatar, the caller's name (`headlineMedium`, or
/// `titleLarge` in landscape) and the status line (`bodyMedium`, 8dp below).
///
/// Signal puts its logo before the kind label; this app can wear a disguise
/// icon on the home screen, so the glyph names the call, never the app.
class IncomingCallHeader extends StatelessWidget {
  const IncomingCallHeader({
    super.key,
    required this.kindLabel,
    required this.video,
    required this.name,
    required this.avatarUrl,
    required this.status,
    required this.landscape,
  });

  final String kindLabel;
  final bool video;
  final String name;
  final String? avatarUrl;
  final String? status;
  final bool landscape;

  static const avatarSize = 80.0;

  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    final body = type.bodyMedium?.copyWith(
      color: Colors.white,
      shadows: callTextShadow,
    );
    final title = (landscape ? type.titleLarge : type.headlineMedium)?.copyWith(
      color: Colors.white,
      shadows: callTextShadow,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          // Signal: 22 above / 30 below in portrait, 0 / 20 in landscape.
          padding: landscape
              ? const EdgeInsets.only(bottom: 20)
              : const EdgeInsets.only(top: 22, bottom: 30),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                // Not the Answer glyphs: those name the button, this names the call.
                video
                    ? Icons.video_call_outlined
                    : Icons.phone_in_talk_outlined,
                size: 16,
                color: Colors.white,
                shadows: callTextShadow,
              ),
              const SizedBox(width: 6),
              Text(kindLabel, style: body),
            ],
          ),
        ),
        _Avatar(url: avatarUrl, name: name),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            name,
            style: title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (status != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(status!, style: body),
          ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.name});

  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final src = url?.trim();
    final initial = ColoredBox(
      color: colors.primaryContainer,
      child: Center(
        child: Text(
          displayNameInitial(name) ?? '?',
          style: TextStyle(
            fontSize: IncomingCallHeader.avatarSize * 0.4,
            fontWeight: FontWeight.w600,
            color: colors.onPrimaryContainer,
          ),
        ),
      ),
    );
    return SizedBox.square(
      dimension: IncomingCallHeader.avatarSize,
      child: ClipOval(
        child: src == null || src.isEmpty
            ? initial
            : CachedNetworkImage(
                cacheManager: AvatarCache.instance,
                imageUrl: src,
                fit: BoxFit.cover,
                placeholder: (_, _) => initial,
                errorWidget: (_, _, _) => initial,
              ),
      ),
    );
  }
}
