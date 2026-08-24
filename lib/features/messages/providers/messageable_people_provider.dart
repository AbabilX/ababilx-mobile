import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat_connection.dart';
import 'chat_connections_provider.dart';
import 'chat_provider.dart';
import 'team_gate_provider.dart';

final messageablePeopleProvider = Provider<List<ChatUserSummary>>((ref) {
  final me = ref.watch(chatProvider).currentUserId;
  final people = <String, ChatUserSummary>{};
  for (final connection in ref.watch(chatConnectionsProvider).connections) {
    people[connection.user.userId] = connection.user;
  }
  for (final member in ref.watch(teamMembersProvider)) {
    if (member.userId == me) continue;
    people.putIfAbsent(
      member.userId,
      () => ChatUserSummary(
        userId: member.userId,
        name: member.displayName,
        avatarUrl: member.avatarUrl ?? '',
        sharedWorkspace: true,
        canMessage: true,
      ),
    );
  }
  final result = people.values.toList();
  result.sort((a, b) => a.name.compareTo(b.name));
  return result;
});
