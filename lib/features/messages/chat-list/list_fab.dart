import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';

class ChatListFab extends StatelessWidget {
  const ChatListFab({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: colors.surfaceContainerHighest,
      foregroundColor: colors.onSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: const ChatIcon(HugeIcons.strokeRoundedAdd01, size: 26),
    );
  }
}
