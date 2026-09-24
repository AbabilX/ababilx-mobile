import 'package:flutter/material.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../data/models/chat_models.dart';

/// Group → Permissions → Add Exception: pick the member to restrict. Admins
/// and members already restricted are left out by the caller.
Future<ChatMember?> pickExceptionMember(
  BuildContext context,
  List<ChatMember> candidates,
) {
  return showModalBottomSheet<ChatMember>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheet).height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final m in candidates)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: ClipOval(
                  child: AppAvatar(size: 40, url: m.avatarUrl, name: m.name),
                ),
                title: Text(m.name),
                onTap: () => Navigator.pop(sheet, m),
              ),
          ],
        ),
      ),
    ),
  );
}
