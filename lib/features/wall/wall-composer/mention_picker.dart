import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../../messages/providers/team_gate_provider.dart';
import '../../team/data/models/team_models.dart';

Future<TeamMember?> showWallMentionPicker(
  BuildContext context,
  WidgetRef ref,
) {
  final members = ref.read(teamMembersProvider);
  return showModalBottomSheet<TeamMember>(
    context: context,
    builder: (ctx) {
      return SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: members.length,
          itemBuilder: (_, i) {
            final m = members[i];
            return ListTile(
              leading: AppAvatar(
                size: 36,
                name: m.displayName,
                url: m.avatarUrl,
              ),
              title: Text(m.displayName),
              onTap: () => Navigator.pop(ctx, m),
            );
          },
        ),
      );
    },
  );
}
