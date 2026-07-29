import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';

Future<String?> showComposeSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const ChatIcon(HugeIcons.strokeRoundedBubbleChat),
            title: const Text('New message'),
            onTap: () => Navigator.pop(ctx, 'dm'),
          ),
          ListTile(
            leading: const ChatIcon(HugeIcons.strokeRoundedUserGroup),
            title: const Text('New group'),
            onTap: () => Navigator.pop(ctx, 'group'),
          ),
        ],
      ),
    ),
  );
}
