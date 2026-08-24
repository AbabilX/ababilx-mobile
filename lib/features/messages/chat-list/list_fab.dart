import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';

class ChatListFab extends StatelessWidget {
  const ChatListFab({
    super.key,
    required this.onCamera,
    required this.onNewMessage,
  });

  final VoidCallback onCamera;
  final VoidCallback onNewMessage;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          heroTag: 'chat-camera',
          onPressed: onCamera,
          backgroundColor: colors.surfaceContainerHighest,
          foregroundColor: colors.onSurface,
          icon: HugeIcons.strokeRoundedCamera01,
        ),
        const SizedBox(height: 16),
        _ActionButton(
          heroTag: 'chat-new-message',
          onPressed: onNewMessage,
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.onPrimaryContainer,
          icon: HugeIcons.strokeRoundedEdit02,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.heroTag,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
  });

  final String heroTag;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final List<List<dynamic>> icon;

  @override
  Widget build(BuildContext context) => FloatingActionButton(
    heroTag: heroTag,
    onPressed: onPressed,
    backgroundColor: backgroundColor,
    foregroundColor: foregroundColor,
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    child: ChatIcon(icon, size: 25),
  );
}
