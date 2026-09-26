import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../data/khaam_covers.dart';
import 'khaam_cover_art.dart';
import 'khaam_envelope_face.dart';

/// How wide the envelope draws inside a card of [cardWidth]: as wide as the
/// card allows, but short enough that envelope, sender and message fit one
/// screen — the open screen cannot scroll while the foil is on.
double khaamEnvelopeWidth(BuildContext context, double cardWidth) => math.min(
  cardWidth - 32,
  MediaQuery.sizeOf(context).height * 0.4 * khaamCoverAspect,
);

/// A Khaam as the receiver holds it: the portrait envelope — memory photo in
/// its upper panel once open, [caption] on its flap (under foil until
/// scratched) — then who sent it and [footer]. The compose screen draws the same
/// card, so what is previewed is what arrives.
class KhaamCard extends StatelessWidget {
  const KhaamCard({
    super.key,
    required this.cover,
    required this.width,
    required this.fromLabel,
    required this.senderName,
    required this.senderAvatar,
    required this.caption,
    this.footer,
    this.photo,
    this.envelopeOverlay,
  });

  final KhaamCover cover;
  final double width;
  final String fromLabel;
  final String senderName;
  final String? senderAvatar;

  /// Written on the envelope's flap: the message, or the foil over it.
  final Widget caption;

  /// Null on the compose preview: there is nothing to press yet.
  final Widget? footer;

  /// The memory photo, sized to [khaamPhotoBox] for the envelope's width.
  final Widget? photo;

  /// Positioned controls over the envelope (the compose screen's pills).
  final Widget? envelopeOverlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return GestureDetector(
      onTap: () {}, // a tap on the card must not close the screen
      child: Container(
        width: width,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: cover.flap.withValues(alpha: 0.35),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: KhaamEnvelopeFace(
                cover: cover,
                width: khaamEnvelopeWidth(context, width),
                photo: photo,
                caption: caption,
                overlay: envelopeOverlay,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppAvatar(size: 28, url: senderAvatar, name: senderName),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    fromLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (footer case final footer?)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
                child: footer,
              )
            else
              const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
