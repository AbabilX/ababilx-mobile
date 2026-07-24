import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';

/// Left app-bar: workspace avatar + name + chevron (tap no-op for now).
class WorkspaceTitle extends StatelessWidget {
  const WorkspaceTitle({
    super.key,
    required this.name,
    this.avatarUrl,
  });

  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        _WorkspaceAvatar(name: name, url: avatarUrl),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
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

class _WorkspaceAvatar extends StatelessWidget {
  const _WorkspaceAvatar({required this.name, this.url});
  final String name;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 32,
        height: 32,
        child: url != null && url!.isNotEmpty
            ? CachedNetworkImage(imageUrl: url!, fit: BoxFit.cover)
            : ColoredBox(
                color: colors.primaryContainer,
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'W',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
