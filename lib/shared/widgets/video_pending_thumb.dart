import 'package:flutter/material.dart';

class VideoPendingThumb extends StatelessWidget {
  const VideoPendingThumb({
    super.key,
    required this.placeholderColor,
    this.size = 72,
  });

  final Color placeholderColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: placeholderColor,
      child: SizedBox(
        width: size,
        height: size,
        child: const Center(
          child: Icon(Icons.play_circle_outline_rounded, size: 32),
        ),
      ),
    );
  }
}
