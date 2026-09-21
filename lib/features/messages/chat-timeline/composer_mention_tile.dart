import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../../profile/providers/user_status_provider.dart';
import 'composer_mention_picker.dart';

/// One row of the `@` popover: 44dp photo, name, and a second line — the
/// person's status for a member, why they are separate for an outsider.
class MentionTile extends ConsumerWidget {
  const MentionTile({super.key, required this.candidate, required this.onTap});

  final MentionCandidate candidate;
  final ValueChanged<MentionCandidate> onTap;

  static const double _avatar = 44;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final c = candidate;
    final status = c.isAll || !c.isInChannel
        ? null
        : ref.watch(userStatusForProvider(c.userId));

    final String? subtitle;
    if (c.isAll) {
      subtitle = 'Mention all members in this chat';
    } else if (!c.isInChannel) {
      subtitle = 'Not in this group';
    } else if (status != null && status.isActive) {
      subtitle = '${status.emoji} ${status.text}'.trim();
    } else {
      subtitle = null;
    }

    return InkWell(
      onTap: () => onTap(c),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            c.isAll
                ? SizedBox(
                    width: _avatar,
                    height: _avatar,
                    child: Icon(
                      Icons.groups_outlined,
                      size: 28,
                      color: colors.onSurfaceVariant,
                    ),
                  )
                : AppAvatar(
                    size: _avatar,
                    url: c.avatarUrl,
                    name: c.displayName,
                  ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    c.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, color: colors.onSurface),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
