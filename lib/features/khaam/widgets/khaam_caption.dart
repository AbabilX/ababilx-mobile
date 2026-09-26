import 'package:flutter/material.dart';

import '../data/khaam_covers.dart';

/// The message, written on the envelope's flap in the cover's ink: two lines
/// at most, shrunk to fit the flap rather than spilling out of the envelope; pops to full
/// size the moment the foil over it lifts.
class KhaamCaption extends StatelessWidget {
  const KhaamCaption({
    super.key,
    required this.cover,
    required this.text,
    this.sealed = false,
  });

  final KhaamCover cover;
  final String text;
  final bool sealed;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.expand();
    return Center(
      child: AnimatedScale(
        scale: sealed ? 0.92 : 1,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutBack,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cover.ink,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                height: 1.25,
                shadows: const [Shadow(blurRadius: 6, color: Colors.black26)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
