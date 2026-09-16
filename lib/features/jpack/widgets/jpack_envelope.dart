import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../data/jpack_covers.dart';
import '../data/jpack_payload.dart';
import 'jpack_cover_art.dart';
import 'jpack_envelope_parts.dart';

/// How wide the envelope draws on this screen.
double jpackEnvelopeWidth(BuildContext context) =>
    math.min(MediaQuery.sizeOf(context).width * 0.78, 320.0);

/// The sealed JPack: flap, upper panel and seal, torn apart as [open] runs
/// from 0 to 1. The open screen owns the controllers and the drag.
class JPackEnvelope extends StatelessWidget {
  const JPackEnvelope({
    super.key,
    required this.width,
    required this.cover,
    required this.payload,
    required this.senderName,
    required this.senderAvatar,
    required this.fromLabel,
    required this.openLabel,
    required this.swipeLabel,
    required this.open,
    required this.spin,
    required this.onSealTap,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final double width;
  final JPackCover cover;
  final JPackPayload payload;
  final String senderName;
  final String? senderAvatar;
  final String fromLabel;
  final String openLabel;
  final String swipeLabel;
  final Animation<double> open;
  final Animation<double> spin;
  final VoidCallback onSealTap;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final height = width / jpackCoverAspect;
    final seal = jpackSealCenter(Size(width, height));
    final sealR = jpackSealRadius(Size(width, height));

    final heading = Padding(
      padding: EdgeInsets.fromLTRB(20, height * 0.08, 20, 0),
      child: Column(
        children: [
          AppAvatar(size: 48, url: senderAvatar, name: senderName),
          const SizedBox(height: 10),
          Text(
            fromLabel,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cover.ink,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              shadows: const [Shadow(blurRadius: 6, color: Colors.black26)],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            payload.message,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cover.ink,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.3,
              shadows: const [Shadow(blurRadius: 8, color: Colors.black26)],
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onVerticalDragUpdate: onDragUpdate,
      onVerticalDragEnd: onDragEnd,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: width,
            height: height,
            child: AnimatedBuilder(
              animation: Listenable.merge([open, spin]),
              builder: (context, _) {
                final p = Curves.easeIn.transform(open.value);
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // The flap drops away first…
                    Transform.translate(
                      offset: Offset(0, p * height * 0.6),
                      child: Opacity(
                        opacity: (1 - p * 1.4).clamp(0.0, 1.0),
                        child: ClipPath(
                          clipper: JPackPathClipper(jpackLowerPath),
                          child: JPackCoverArt(
                            cover: cover,
                            width: width,
                            part: JPackCoverPart.lower,
                            showSeal: false,
                          ),
                        ),
                      ),
                    ),
                    // …while the upper panel lifts off, tipping back in 3D.
                    Transform(
                      alignment: Alignment.topCenter,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0015)
                        ..translateByDouble(0.0, -p * height * 0.7, 0.0, 1.0)
                        ..rotateX(p * 1.1),
                      child: Opacity(
                        opacity: (1 - p * 1.2).clamp(0.0, 1.0),
                        child: ClipPath(
                          clipper: JPackPathClipper(jpackUpperPath),
                          child: JPackCoverArt(
                            cover: cover,
                            width: width,
                            part: JPackCoverPart.upper,
                            showSeal: false,
                            child: heading,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: seal.dx - sealR * 1.15,
                      top: seal.dy - sealR * 1.15 + p * height * 0.2,
                      width: sealR * 2.3,
                      height: sealR * 2.3,
                      child: Opacity(
                        opacity: (1 - p * 1.6).clamp(0.0, 1.0),
                        child: GestureDetector(
                          onTap: onSealTap,
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.002)
                              ..rotateY(spin.value * math.pi * 4),
                            child: JPackPulsingSeal(
                              child: JPackSeal(cover: cover, label: openLabel),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 22),
          AnimatedBuilder(
            animation: open,
            builder: (_, child) => Opacity(
              opacity: (1 - open.value * 2).clamp(0.0, 1.0),
              child: child,
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.keyboard_double_arrow_up_rounded,
                  color: Colors.white70,
                ),
                const SizedBox(height: 4),
                Text(
                  swipeLabel,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
