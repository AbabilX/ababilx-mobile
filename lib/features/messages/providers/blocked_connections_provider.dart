import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/first_load_timeout.dart';
import '../data/chat_repository.dart';
import '../data/models/chat_connection.dart';

/// The server returns only blocks owned by the signed-in user.
final blockedConnectionsProvider =
    FutureProvider.autoDispose<List<ChatConnection>>(
      (ref) => ref
          .watch(chatRepositoryProvider)
          .listBlockedUsers()
          .timeout(firstLoadNetworkTimeout),
    );
