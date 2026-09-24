import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// The green online mark on a person's avatar. Same colour and ring as the
/// one on your own picture in the chat-list header, so the two read as one
/// signal.
class OnlineDot extends StatelessWidget {
  const OnlineDot({super.key, this.size = 14});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.green,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.surface,
          width: size > 12 ? 2 : 1.5,
        ),
      ),
    );
  }
}
