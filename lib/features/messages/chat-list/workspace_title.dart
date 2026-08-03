import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../chat_icon.dart';

/// Left app-bar: workspace avatar + name + chevron (tap no-op for now).
class WorkspaceTitle extends StatelessWidget {
  const WorkspaceTitle({super.key, required this.name, this.avatarUrl});

  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        AppAvatar(
          size: 32,
          url: avatarUrl,
          name: name,
          backgroundColor: colors.primaryContainer,
          letterStyle: TextStyle(
            fontWeight: FontWeight.w800,
            color: colors.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 2),
        ChatIcon(
          HugeIcons.strokeRoundedArrowDown01,
          size: 18,
          color: colors.onSurfaceVariant,
        ),
      ],
    );
  }
}
