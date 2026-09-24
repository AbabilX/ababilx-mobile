import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'user_permissions_screen.dart';

/// `/messages/:id/members/:userId/permissions`. The member rides in `extra`
/// from the roster; a cold entry (a restored route) has none, so it is read
/// back from the roster, where an admin sees everyone's permissions.
class MemberPermissionsRoute extends ConsumerWidget {
  const MemberPermissionsRoute({
    super.key,
    required this.conversationId,
    required this.userId,
    this.member,
  });

  final String conversationId;
  final String userId;
  final ChatMember? member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final known = member;
    if (known != null) {
      return UserPermissionsScreen(
        conversationId: conversationId,
        member: known,
      );
    }
    return FutureBuilder<List<ChatMember>>(
      future: ref
          .read(chatProvider.notifier)
          .listChannelMembers(conversationId),
      builder: (context, snap) {
        final found = snap.data?.where((m) => m.userId == userId).firstOrNull;
        if (found != null) {
          return UserPermissionsScreen(
            conversationId: conversationId,
            member: found,
          );
        }
        return Scaffold(
          appBar: AppBar(),
          body: Center(
            child: snap.connectionState == ConnectionState.done
                ? const Text('Member not found')
                : const CircularProgressIndicator(strokeWidth: 2.5),
          ),
        );
      },
    );
  }
}
