import 'package:flutter/material.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../../team/data/models/team_models.dart';
import '../data/models/wall_models.dart';

class ComposerSuggestionPanel extends StatelessWidget {
  const ComposerSuggestionPanel({
    super.key,
    required this.isMention,
    required this.members,
    required this.categories,
    required this.onPickMember,
    required this.onPickCategory,
  });

  final bool isMention;
  final List<TeamMember> members;
  final List<WallCategory> categories;
  final ValueChanged<TeamMember> onPickMember;
  final ValueChanged<WallCategory> onPickCategory;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final empty = isMention ? members.isEmpty : categories.isEmpty;

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 180),
        child: empty
            ? Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  isMention ? 'No members found' : 'No categories found',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: isMention ? members.length : categories.length,
                itemBuilder: (_, i) {
                  if (isMention) {
                    final m = members[i];
                    return ListTile(
                      dense: true,
                      leading: AppAvatar(
                        size: 28,
                        name: m.displayName,
                        url: m.avatarUrl,
                      ),
                      title: Text(m.displayName),
                      onTap: () => onPickMember(m),
                    );
                  }
                  final c = categories[i];
                  return ListTile(
                    dense: true,
                    leading: Text(
                      '#',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                    ),
                    title: Text(c.label),
                    subtitle: c.description == null || c.description!.isEmpty
                        ? null
                        : Text(c.description!),
                    onTap: () => onPickCategory(c),
                  );
                },
              ),
      ),
    );
  }
}
