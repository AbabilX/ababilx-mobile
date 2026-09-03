import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../shared/text/display_name.dart';

/// Web `ContactAvatar` — image or initials.
class ContactAvatar extends StatelessWidget {
  const ContactAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 20,
  });

  final String name;
  final String? imageUrl;
  final double radius;

  String get _initial => displayNameInitial(name) ?? '?';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final url = (imageUrl ?? '').trim();

    if (url.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: colors.primaryContainer,
        backgroundImage: CachedNetworkImageProvider(url),
        onBackgroundImageError: (_, _) {},
        child: null,
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.primaryContainer,
      foregroundColor: colors.onPrimaryContainer,
      child: Text(
        _initial,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: colors.onPrimaryContainer,
          fontSize: radius * 0.75,
        ),
      ),
    );
  }
}
