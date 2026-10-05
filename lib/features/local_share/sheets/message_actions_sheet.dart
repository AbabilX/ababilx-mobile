import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../messages/chat_icon.dart';
import '../../share_intake/data/shared_payload.dart';
import '../../share_intake/providers/share_intake_provider.dart';
import '../data/received_files_store.dart';
import '../data/share_thread_queries.dart';
import '../engine/store/share_records.dart';
import '../local_share_actions.dart';
import '../local_share_engine.dart';
import '../share_text.dart';

enum _Action { save, forward, retry, cancel, deleteMe, deleteBoth }

/// Long press on a bubble: what can be done with this one message.
Future<void> showShareMessageActions(
  BuildContext context,
  WidgetRef ref,
  LocalShareEngine engine,
  ShareBubbleData data,
) async {
  final message = data.message;
  final moving =
      message.status == ShareMessageStatus.sending ||
      message.status == ShareMessageStatus.receiving;
  final ready = [
    for (final f in data.files)
      if ((f.done || message.fromMe) && File(f.localPath).existsSync()) f,
  ];
  final text = message.text ?? '';

  final action = await showModalBottomSheet<_Action>(
    context: context,
    showDragHandle: true,
    builder: (sheet) {
      Widget row(
        _Action a,
        String key,
        List<List<dynamic>> icon, {
        bool danger = false,
      }) {
        final color = danger ? Theme.of(sheet).colorScheme.error : null;
        return ListTile(
          leading: ChatIcon(icon, color: color),
          title: Text(lsText(ref, key), style: TextStyle(color: color)),
          onTap: () => Navigator.pop(sheet, a),
        );
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ready.isNotEmpty && !message.fromMe)
              row(
                _Action.save,
                'ls_action_save',
                HugeIcons.strokeRoundedDownload04,
              ),
            if (ready.isNotEmpty || text.isNotEmpty)
              row(
                _Action.forward,
                'ls_action_forward',
                HugeIcons.strokeRoundedArrowTurnForward,
              ),
            if (message.fromMe && message.status == ShareMessageStatus.failed)
              row(
                _Action.retry,
                'ls_action_retry',
                HugeIcons.strokeRoundedRefresh,
              ),
            if (message.fromMe && moving)
              row(
                _Action.cancel,
                'ls_action_cancel',
                HugeIcons.strokeRoundedCancel01,
              ),
            row(
              _Action.deleteMe,
              'ls_action_delete_me',
              HugeIcons.strokeRoundedDelete02,
              danger: true,
            ),
            if (message.fromMe)
              row(
                _Action.deleteBoth,
                'ls_action_delete_both',
                HugeIcons.strokeRoundedDelete01,
                danger: true,
              ),
          ],
        ),
      );
    },
  );
  if (action == null || !context.mounted) return;

  switch (action) {
    case _Action.save:
      var saved = 0;
      for (final file in ready) {
        try {
          await ReceivedFilesStore.publishCopy(file.localPath, file.name);
          saved++;
        } catch (_) {}
      }
      if (!context.mounted) return;
      showAppToast(
        context,
        lsText(ref, saved == ready.length ? 'ls_saved' : 'ls_save_failed'),
        isError: saved != ready.length,
      );
    case _Action.forward:
      // The chat's own share screen takes it from here: pick a chat, and only
      // then is anything uploaded to the server.
      ref
          .read(shareIntakeProvider.notifier)
          .offer(
            SharedPayload(
              text: text,
              files: [
                for (final f in ready)
                  SharedFile(
                    uri: Uri.file(f.localPath).toString(),
                    fileName: f.name,
                    contentType: f.mime,
                    sizeBytes: f.size,
                  ),
              ],
            ),
          );
    case _Action.retry:
      await engine.sender.retry(message.id);
    case _Action.cancel:
      await engine.sender.cancel(message.id);
    case _Action.deleteMe:
      await engine.deleteForMe(message.id);
    case _Action.deleteBoth:
      await engine.deleteForBoth(message.id);
  }
}
