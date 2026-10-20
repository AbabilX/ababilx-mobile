import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/friendly_error.dart';
import '../../../shared/widgets/app_toast.dart';
import '../chat_icon.dart';
import 'scheduled_api.dart';
import 'scheduled_message.dart';
import '../../home/data/home_drafts.dart';
import 'scheduled_provider.dart';
import 'scheduled_reseal.dart';
import 'send_later_sheet.dart';
import 'send_later_times.dart';
import 'send_later_words.dart';

enum _Action { sendNow, changeTime, delete }

/// One scheduled message's actions, as a bottom sheet. The sheet only
/// chooses; the work runs here, on the caller's context, because the sheet
/// is gone by the time the request answers.
Future<void> showScheduledActions(
  BuildContext context,
  WidgetRef ref,
  ScheduledMessage row,
) async {
  final action = await showModalBottomSheet<_Action>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionTile(
            icon: HugeIcons.strokeRoundedSent,
            label: 'Send now',
            onTap: () => Navigator.of(sheet).pop(_Action.sendNow),
          ),
          _ActionTile(
            icon: HugeIcons.strokeRoundedCalendar03,
            label: 'Change time',
            onTap: () => Navigator.of(sheet).pop(_Action.changeTime),
          ),
          _ActionTile(
            icon: HugeIcons.strokeRoundedDelete02,
            label: 'Delete',
            danger: true,
            onTap: () => Navigator.of(sheet).pop(_Action.delete),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  DateTime? at;
  if (action == _Action.changeTime) {
    at = await showSendLaterSheet(
      context,
      title: 'Change time',
      action: 'Save',
    );
    if (at == null || !context.mounted) return;
  }
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  final client = ref.read(apiClientProvider);
  final reseal = ref.read(scheduledResealProvider);
  void refresh() {
    ref.invalidate(scheduledMessagesProvider(row.conversationId));
    ref.invalidate(homeScheduledProvider);
  }

  try {
    switch (action) {
      case _Action.sendNow:
        await _sendNow(client, reseal, row);
        showAppToastIn(overlay, 'Sent');
      case _Action.changeTime:
        await patchScheduled(client, row.id, sendAt: at);
        showAppToastIn(overlay, 'Scheduled for ${formatSendAt(at!)}');
      case _Action.delete:
        await deleteScheduled(client, row.id);
        showAppToastIn(overlay, 'Deleted');
    }
  } catch (error) {
    showAppToastIn(overlay, sendLaterErrorText(error), isError: true);
  }
  refresh();
}

/// A message sealed under a key that has moved cannot be sent as it is:
/// this phone seals it again and asks once more.
Future<void> _sendNow(
  ApiClient client,
  ScheduledReseal reseal,
  ScheduledMessage row,
) async {
  try {
    await sendScheduledNow(client, row.id);
  } catch (error) {
    final code = serverErrorCode(error);
    final stale =
        code == 'chat_key_rotation_required' ||
        code == 'message encryption key unavailable';
    if (!stale) rethrow;
    final rows = await listScheduled(client, row.conversationId);
    await reseal.run(rows.where((r) => r.id == row.id).toList());
    await sendScheduledNow(client, row.id);
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final List<List<dynamic>> icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ink = danger ? colors.error : colors.onSurface;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            ChatIcon(icon, size: 20, color: ink),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
