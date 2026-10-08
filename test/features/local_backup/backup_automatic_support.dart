import 'dart:io';

import 'package:ababilx/features/local-backup/auto/account_backup_dir.dart';
import 'package:ababilx/features/local-backup/auto/backup_media_store.dart';
import 'package:ababilx/features/local-backup/data/backup_choices.dart';
import 'package:ababilx/features/local-backup/export/backup_exporter.dart';
import 'package:ababilx/features/local-backup/format/backup_file_writer.dart';
import 'package:ababilx/features/messages/data/models/chat_attachment.dart';
import 'package:ababilx/features/messages/data/models/chat_conversation.dart';
import 'package:ababilx/features/messages/data/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessageAttachment att(String name) => ChatMessageAttachment(
  id: name,
  messageId: 'x',
  fileName: name,
  fileUrl: 'https://cdn/$name',
  contentType: 'video/mp4',
  sizeBytes: 3,
  uploadedBy: 'u',
  createdAt: '',
);

ChatMessage msg(String id, List<String> files) => ChatMessage(
  id: id,
  conversationId: 'dm',
  userId: 'peer',
  body: 'plain $id',
  createdAt: DateTime.utc(2026, 10, 8, 10, id.length).toIso8601String(),
  attachments: [for (final f in files) att(f)],
);

final backupTestKey = List<int>.generate(32, (i) => i * 5);
final backupTestDm = ChatConversation.fromJson({
  'id': 'dm',
  'type': 'dm',
  'name': 'dm',
});

/// One automatic run over [store]; [onPhone] are the files still on disk.
Future<BackupMediaStore> runAutomatic(
  AccountBackupDir dir,
  List<ChatMessage> store,
  Map<String, File> onPhone,
  int stamp, {
  int free = 1 << 40,
  int reserve = 0,
}) async {
  final name = 'me-$stamp.abxbackup';
  final media = BackupMediaStore(
    dir: dir.media,
    accountKey: backupTestKey,
    userId: 'me',
    freeBytes: free,
    reserveBytes: reserve,
  );
  final partial = await dir.partial(name);
  final writer = await BackupFileWriter.create(
    partial,
    accountKey: backupTestKey,
    userId: 'me',
    createdAtMs: stamp,
  );
  var reads = 0;
  await BackupExporter(
    readPage: (_, _) async => reads++ == 0 ? store : const [],
    allows: (_) => true,
    openBody: (_) async => null,
    localFile: (url) async => onPhone[url],
    choices: const BackupChoices(),
    conversations: {'dm': backupTestDm},
    media: media,
  ).run(writer);
  await writer.close();
  await dir.commit(partial, name, media.wanted);
  return media;
}
