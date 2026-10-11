import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';
import 'scheduled_list_sheet.dart';
import 'scheduled_provider.dart';

/// The capsule above a composer while it has messages waiting to be sent:
/// "2 scheduled". Nothing is drawn in the timeline until the server sends
/// one; this is where the sender finds them. Red when one was refused.
class ScheduledBar extends ConsumerWidget {
  const ScheduledBar({super.key, required this.conversationId, this.parentId});

  final String conversationId;
  final String? parentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = scheduledFor(
      ref.watch(scheduledMessagesProvider(conversationId)).valueOrNull ??
          const [],
      parentId,
    );
    if (rows.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final failed = rows.where((r) => r.failed).length;
    final ink = failed > 0 ? colors.error : colors.onSurface;
    return Align(
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Material(
          color: colors.surfaceContainerHighest,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => showScheduledListSheet(
              context,
              conversationId: conversationId,
              parentId: parentId,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ChatIcon(
                    HugeIcons.strokeRoundedClock01,
                    size: 16,
                    color: ink,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    failed > 0
                        ? '$failed not sent'
                        : '${rows.length} scheduled',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
