import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import 'you_menu_item.dart';

class YouMenu extends StatelessWidget {
  const YouMenu({super.key});

  void _soon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        YouMenuItem(
          icon: HugeIcons.strokeRoundedNotificationOff01,
          label: 'Pause notifications',
          onTap: () => _soon(context, 'Pause notifications'),
        ),
        YouMenuItem(
          icon: HugeIcons.strokeRoundedUser,
          label: 'Set yourself as away',
          onTap: () => _soon(context, 'Away status'),
        ),
        const Divider(height: 20, indent: 20, endIndent: 20),
        YouMenuItem(
          icon: HugeIcons.strokeRoundedBuilding03,
          label: 'Invitations to connect',
          onTap: () => _soon(context, 'Invitations'),
        ),
        YouMenuItem(
          icon: HugeIcons.strokeRoundedUserCircle,
          label: 'View profile',
          onTap: () {
            Navigator.pop(context);
            context.go('/profile');
          },
        ),
        YouMenuItem(
          icon: HugeIcons.strokeRoundedSmartPhone01,
          label: 'Notifications',
          onTap: () => _soon(context, 'Notifications'),
        ),
        YouMenuItem(
          icon: HugeIcons.strokeRoundedSettings01,
          label: 'Preferences',
          onTap: () => _soon(context, 'Preferences'),
        ),
      ],
    );
  }
}
