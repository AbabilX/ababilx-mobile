import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/media/save_to_phone.dart';
import '../../../shared/media/save_to_phone_action.dart';
import '../../../shared/media/save_to_phone_dialog.dart';
import '../../attachments/providers/attachment_providers.dart';
import '../data/models/chat_models.dart';
import '../../chat-lock/data/chat_lock_index.dart';

/// Which attachments a "Save" on this message would actually write.
///
/// A locked one is withheld by retention and has no bytes anywhere, so a
/// message holding nothing else must not offer the action at all.
List<ChatMessageAttachment> saveableAttachments(ChatMessage message) {
  // A locked chat keeps its files off this phone's storage, Save included.
  if (ChatLockIndex.cached.containsKey(message.conversationId)) return const [];
  return message.attachments
      .where((a) => !a.locked && !a.isProtected && a.fileUrl.isNotEmpty)
      .toList();
}

bool canSaveMessageAttachments(ChatMessage message) =>
    saveableAttachments(message).isNotEmpty;

/// Signal's Save on a media message: every attachment it carries, one
/// confirmation, one result line.
///
/// Anything not on disk yet is fetched first — the user asked for the file, so
/// "not downloaded" is a wait, not a refusal. A fetch that fails simply drops
/// out of the batch and is reported in the "saved n of m" count.
Future<void> saveMessageAttachments(
  BuildContext context,
  WidgetRef ref,
  ChatMessage message,
) async {
  final wanted = saveableAttachments(message);
  if (wanted.isEmpty) return;
  if (!await confirmSaveToPhone(context, fileCount: wanted.length)) return;
  if (!context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final authority = ref.read(attachmentAuthorityProvider);

  // Resolve without fetching first: photos and voice notes are already on disk,
  // and flashing "Saving…" for a copy that takes a few milliseconds is worse
  // than showing nothing. Only a real transfer earns the notice.
  final onDisk = await authority.resolveAll(wanted);
  final needsFetch = onDisk.any((h) => !h.isReady);
  if (needsFetch) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Saving…'), duration: Duration(minutes: 1)),
    );
  }
  final handles = await Future.wait(wanted.map(authority.require));
  if (needsFetch) messenger.hideCurrentSnackBar();
  if (!context.mounted) return;

  final requests = <SaveToPhoneRequest>[];
  for (var i = 0; i < wanted.length; i++) {
    final handle = handles[i];
    if (!handle.isReady) continue;
    requests.add(
      SaveToPhoneRequest(
        sourcePath: handle.localPath!,
        fileName: wanted[i].fileName,
        contentType: wanted[i].contentType,
      ),
    );
  }
  await saveConfirmedToPhone(context, requests, expected: wanted.length);
}
