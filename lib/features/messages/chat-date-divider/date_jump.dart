import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../chat-timeline/timeline_jump.dart';
import '../chat_utils.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';

/// Where a day-marker tap can go: a few quick spots, or any date.
Future<void> showDateJumpSheet(
  BuildContext context,
  WidgetRef ref, {
  required String conversationId,
  String? threadRootId,
}) async {
  String t(String key) => AppTranslations.translate(context, ref, key);
  // Taken before the sheet opens: the list's own context is the one that sits
  // under the jump scope.
  final jump = TimelineJumpScope.maybeOf(context);
  if (jump == null) return;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final picked = await showModalBottomSheet<DateTime>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                t('date_jump_title'),
                style: Theme.of(sheet).textTheme.titleMedium,
              ),
            ),
          ),
          _row(
            sheet,
            t('date_jump_yesterday'),
            today.subtract(const Duration(days: 1)),
          ),
          _row(
            sheet,
            t('date_jump_week'),
            today.subtract(const Duration(days: 7)),
          ),
          _row(
            sheet,
            t('date_jump_month'),
            DateTime(today.year, today.month - 1, today.day),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: Text(t('date_jump_pick')),
            onTap: () async {
              final date = await showDatePicker(
                context: sheet,
                initialDate: today,
                firstDate: DateTime(2020),
                lastDate: today,
              );
              if (date != null && sheet.mounted) Navigator.of(sheet).pop(date);
            },
          ),
        ],
      ),
    ),
  );
  if (picked == null || !context.mounted) return;
  final found = await _jumpToDay(
    ref,
    jump,
    conversationId: conversationId,
    threadRootId: threadRootId,
    day: picked,
  );
  if (!found && context.mounted) showAppToast(context, t('date_jump_none'));
}

Widget _row(BuildContext sheet, String label, DateTime day) => ListTile(
  leading: const Icon(Icons.history),
  title: Text(label),
  onTap: () => Navigator.of(sheet).pop(day),
);

DateTime _dayOf(ChatMessage m) {
  final local = (DateTime.tryParse(m.createdAt) ?? DateTime(1970)).toLocal();
  return DateTime(local.year, local.month, local.day);
}

bool _isRow(ChatMessage m) => !m.isSystem && !m.isVoiceCall && !m.isGroupCall;

/// Lands on the first message of [day] — or the next day that has one — paging
/// older history in until the loaded feed reaches back that far.
Future<bool> _jumpToDay(
  WidgetRef ref,
  TimelineJumpController jump, {
  required String conversationId,
  required String? threadRootId,
  required DateTime day,
}) async {
  final key = feedKey(conversationId, threadRootId: threadRootId);
  for (var step = 0; step < 60; step++) {
    final feed = ref.read(chatProvider).feeds[key];
    final messages = feed?.messages ?? const <ChatMessage>[];
    final reachedBack =
        messages.isNotEmpty && !_dayOf(messages.first).isAfter(day);
    if (reachedBack || !(feed?.hasMore ?? false)) {
      for (final m in messages) {
        if (_isRow(m) && !_dayOf(m).isBefore(day)) return jump.jumpTo(m.id);
      }
      return false;
    }
    await ref
        .read(chatProvider.notifier)
        .loadMoreFeed(conversationId, threadRootId: threadRootId);
    // A page already in flight makes the call above return at once.
    for (var wait = 0; wait < 200; wait++) {
      if (!(ref.read(chatProvider).feeds[key]?.loadingMore ?? false)) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
  return false;
}
