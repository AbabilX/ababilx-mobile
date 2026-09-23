import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/first_load_timeout.dart';
import '../data/chat_repository.dart';

/// The caller's one pinned message in this conversation, if still visible.
final pinnedMessageProvider = FutureProvider.autoDispose
    .family<String?, String>(
      (ref, conversationId) => ref
          .watch(chatRepositoryProvider)
          .pinnedMessage(conversationId)
          .timeout(firstLoadNetworkTimeout),
    );
