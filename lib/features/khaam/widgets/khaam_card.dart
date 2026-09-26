import 'package:flutter/material.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../data/khaam_covers.dart';
import 'khaam_cover_band.dart';

/// The open screen's card: the cover's motif on top with who sent it, then
/// [body] (the message, under foil until scratched) and [footer].
class KhaamCard extends StatelessWidget {
  const KhaamCard({
    super.key,
    required this.cover,
    required this.width,
    required this.fromLabel,
    required this.senderName,
    required this.senderAvatar,
    required this.body,
    required this.footer,
  });

  final KhaamCover cover;
  final double width;
  final String fromLabel;
  final String senderName;
  final String? senderAvatar;
  final Widget body;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {}, // a tap on the card must not close the screen
      child: Container(
        width: width,
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
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KhaamCoverBand(
              cover: cover,
              width: width,
              height: width * 0.66,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: AppAvatar(
                          size: 48,
                          url: senderAvatar,
                          name: senderName,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        fromLabel,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          shadows: [
                            Shadow(blurRadius: 8, color: Colors.black38),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: body,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: footer,
            ),
          ],
        ),
      ),
    );
  }
}
