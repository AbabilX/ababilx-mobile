import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';

class WallFab extends StatelessWidget {
  const WallFab({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      tooltip: 'Create post',
      child: const ChatIcon(HugeIcons.strokeRoundedEdit02),
    );
  }
}
