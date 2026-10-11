import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../message_e2ee/message_vault.dart';
import '../providers/chat_provider.dart';
import 'scheduled_api.dart';
import 'scheduled_message.dart';
import 'scheduled_reseal.dart';

/// This account's scheduled messages in one conversation (server 0171),
/// soonest first, each opened on this device for the list. Refetched on
/// `chat.scheduled.updated`, which the server sends to the sender's own
/// devices whenever one is stored, moved, sent or refused.
final scheduledMessagesProvider = FutureProvider.autoDispose
    .family<List<ScheduledMessage>, String>((ref, conversationId) async {
      final client = ref.watch(apiClientProvider);
      // No timer of its own: the HTTP client's timeouts bound the request,
      // and a timer here would outlive a chat that was opened and closed.
      var rows = await listScheduled(client, conversationId);
      if (rows.isEmpty) return rows;
      // A row the server could not send for a moved key is repaired here,
      // then read again so the list shows it back in line.
      if (await ref.read(scheduledResealProvider).run(rows) > 0) {
        rows = await listScheduled(client, conversationId);
      }
      final vault = ref.read(messageVaultProvider);
      final userId = await ref
          .read(chatProvider.notifier)
          .ensureCurrentUserId();
      return [
        for (final row in rows)
          row.withOpened(
            await vault.decryptMessage(row.asSealedMessage(userId), userId),
          ),
      ];
    });

/// What a composer shows above itself: the scheduled messages of the place
/// it writes to — the main timeline ([parentId] null) or one thread.
List<ScheduledMessage> scheduledFor(
  List<ScheduledMessage> rows,
  String? parentId,
) => [
  for (final row in rows)
    if (row.parentId == parentId) row,
];
