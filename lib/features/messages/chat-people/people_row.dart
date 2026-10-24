import 'package:flutter/material.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../data/models/chat_connection.dart';

class PeopleRow extends StatelessWidget {
  const PeopleRow({super.key, required this.user, required this.trailing});

  final ChatUserSummary user;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    // A nameless person's title already IS their handle; do not repeat it.
    final detail = user.username.isNotEmpty && !user.name.startsWith('@')
        ? '@${user.username}'
        : null;
    return ListTile(
      leading: AppAvatar(size: 42, url: user.avatarUrl, name: user.name),
      title: Text(user.name),
      subtitle: detail == null ? null : Text(detail),
      trailing: trailing,
    );
  }
}
