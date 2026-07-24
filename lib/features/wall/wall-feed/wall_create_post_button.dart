import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';

/// AppBar action — opens wall composer sheet.
class WallCreatePostButton extends StatelessWidget {
  const WallCreatePostButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: ChatIcon(
          HugeIcons.strokeRoundedEdit02,
          size: 18,
          color: colors.primary,
        ),
        label: Text(
          'Create post',
          style: TextStyle(
            color: colors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
