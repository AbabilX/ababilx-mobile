import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';
import 'scheduled_actions.dart';
import 'scheduled_message.dart';
import 'scheduled_provider.dart';
import 'send_later_times.dart';
import 'send_later_words.dart';

/// The scheduled messages of one composer, soonest first. A tap on one
/// opens its actions: send now, change time, delete. The content is fixed —
/// to change the words, delete it and write it again.
Future<void> showScheduledListSheet(
  BuildContext context, {
  required String conversationId,
  String? parentId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) =>
        _ScheduledList(conversationId: conversationId, parentId: parentId),
  );
}

class _ScheduledList extends ConsumerWidget {
  const _ScheduledList({required this.conversationId, this.parentId});

  final String conversationId;
  final String? parentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = scheduledFor(
      ref.watch(scheduledMessagesProvider(conversationId)).valueOrNull ??
          const [],
      parentId,
    );
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Scheduled messages',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: Text(
                  'Nothing is scheduled.',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: rows.length,
                  itemBuilder: (context, i) => _Row(row: rows[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row({required this.row});

  final ScheduledMessage row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final preview = scheduledPreview(row);
    final when = formatSendAt(row.sendAt);
    return InkWell(
      onTap: () => showScheduledActions(context, ref, row),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: ChatIcon(
                row.failed
                    ? HugeIcons.strokeRoundedAlertCircle
                    : row.isTask
                    ? HugeIcons.strokeRoundedTask01
                    : HugeIcons.strokeRoundedClock01,
                size: 20,
                color: row.failed ? colors.error : colors.onSurface,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (preview.isNotEmpty)
                    Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    row.failed
                        ? '${scheduledFailText(row.failReason)} · $when'
                        : when,
                    style: TextStyle(
                      fontSize: 12,
                      color: row.failed
                          ? colors.error
                          : colors.onSurfaceVariant,
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
