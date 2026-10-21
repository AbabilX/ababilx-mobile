import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../shared/text/display_name.dart';
import '../../attachments/data/models/attachment_url_key.dart';
import '../../attachments/providers/attachment_providers.dart';
import '../../local-backup/export/backup_selection.dart';
import '../../local-backup/export/backup_yield.dart';
import '../../messages/data/local/chat_message_row.dart';
import '../../messages/data/local/chat_message_store.dart';
import '../../messages/message_e2ee/message_vault.dart';
import '../../messages/nickname/contact_nickname_provider.dart';
import '../../messages/nickname/nickname_title.dart';
import '../../profile/providers/profile_provider.dart';
import '../format/chat_export_format.dart';
import 'chat_export_message.dart';
import 'chat_export_sources.dart';
import 'chat_export_staging.dart';
import 'chat_export_zip.dart';

class ChatExportResult {
  const ChatExportResult({
    required this.path,
    required this.chats,
    required this.messages,
    required this.files,
  });

  final String path;
  final int chats;
  final int messages;
  final int files;
}

/// Thrown with a translation key.
class ChatExportFailure implements Exception {
  const ChatExportFailure(this.messageKey);
  final String messageKey;
}

/// Every chat on the phone into one plain zip (user's call, 2026-10-21:
/// everything, no password, protected media included). Reads the phone's
/// own store — the same pages the local backup reads — and opens sealed
/// text with the backup's opener.
class ChatExportRunner {
  ChatExportRunner(this._ref);

  final Ref _ref;

  Future<ChatExportResult> run({
    void Function(int messages)? onProgress,
  }) async {
    final me = _ref.read(profileProvider).valueOrNull;
    final userId = me?.id ?? '';
    if (userId.isEmpty) throw const ChatExportFailure('chat_export_error');
    final vault = _ref.read(messageVaultProvider);
    if (!vault.isUnlocked) {
      throw const ChatExportFailure('local_backup_error_locked');
    }
    final myName = safeDisplayName(me?.name, fallback: namelessUserLabel);
    final store = _ref.read(chatMessageStoreProvider);
    final blobs = _ref.read(attachmentBlobStoreProvider);
    final nicknames = _ref.read(contactNicknamesProvider);
    final conversations = await exportConversations(_ref, userId);
    final open = vault.backupBodyOpener(userId);
    final now = DateTime.now();
    final work = Directory(
      '${(await getTemporaryDirectory()).path}/chat-export/'
      '${now.millisecondsSinceEpoch}',
    );
    await work.create(recursive: true);
    final staging = ChatExportStaging(work);
    final turn = BackupYield();
    var messages = 0;
    var files = 0;

    Future<(File, String)?> local(String url) async {
      final row = await blobs.read(attachmentUrlKey(url));
      final path = row?.localPath ?? '';
      if (path.isEmpty) return null;
      final file = File(path);
      return await file.exists() ? (file, row!.fileName) : null;
    }

    try {
      int? afterMs;
      String? afterId;
      while (true) {
        final page = await store.exportPage(
          afterMs: afterMs,
          afterId: afterId,
          limit: 500,
        );
        if (page.isEmpty) break;
        final kept = page
            .where((m) => messageIncluded(m) && store.deletions.allows(m))
            .toList();
        final texts = await Future.wait(kept.map(open));
        for (var i = 0; i < kept.length; i++) {
          await turn.maybe();
          final m = kept[i];
          final id = m.conversationId;
          if (!staging.has(id)) {
            final c = conversations[id];
            await staging.open(
              id,
              c == null ? 'Chat' : nicknames.titleFor(c, userId),
              c == null || !c.isDm ? 'group' : (c.isSelf ? 'self' : 'dm'),
            );
          }
          final exported = <ExportedFile>[];
          for (final a in m.attachments) {
            final found = a.fileUrl.isEmpty ? null : await local(a.fileUrl);
            final name = exportFileName(a, found?.$2 ?? '', found?.$1);
            String? path;
            if (found != null) {
              final before = staging.mediaFor(id, a.fileUrl);
              path = staging.reserveMedia(id, a.fileUrl, name, found.$1.path);
              if (before == null) files++;
            }
            exported.add(
              ExportedFile(
                name: name,
                type: a.contentType,
                size: a.sizeBytes,
                path: path,
              ),
            );
          }
          final sender = m.userId == userId
              ? myName
              : safeDisplayName(m.userName, fallback: namelessUserLabel);
          await staging.add(
            id,
            exportedMessage(m, text: texts[i], sender: sender, files: exported),
          );
          messages++;
        }
        onProgress?.call(messages);
        afterMs = messageTimeMs(page.last);
        afterId = localMessageRowId(page.last);
      }
      if (messages == 0) throw const ChatExportFailure('chat_export_empty');
      final (manifest, entries) = await staging.finish(
        accountId: userId,
        accountName: myName,
        at: now,
      );
      final out = await chatExportsDir();
      final username = me?.username ?? '';
      final zip = File(
        '${out.path}/${ChatExportFormat.zipName(username, now)}',
      );
      await writeChatExportZip(zip.path, entries);
      debugPrint(
        '[ChatExport] chats=${manifest.chats.length} messages=$messages '
        'files=$files bytes=${await zip.length()}',
      );
      return ChatExportResult(
        path: zip.path,
        chats: manifest.chats.length,
        messages: messages,
        files: files,
      );
    } finally {
      try {
        await work.delete(recursive: true);
      } catch (_) {}
    }
  }
}
