import 'dart:io';

import 'package:ababilx/features/local-backup/data/backup_choices.dart';
import 'package:ababilx/features/local-backup/export/backup_exporter.dart';
import 'package:ababilx/features/local-backup/format/backup_file_writer.dart';
import 'package:ababilx/features/local-backup/restore/backup_importer.dart';
import 'package:ababilx/features/messages/data/models/chat_attachment.dart';
import 'package:ababilx/features/messages/data/models/chat_conversation.dart';
import 'package:ababilx/features/messages/data/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

ChatConversation conv(String id, String type, {bool privateChat = false}) =>
    ChatConversation.fromJson({
      'id': id,
      'type': type,
      'name': id,
      'private_chat': privateChat,
    });

ChatMessageAttachment att(String name, String type, {bool noSave = false}) =>
    ChatMessageAttachment(
      id: name,
      messageId: 'x',
      fileName: name,
      fileUrl: 'https://cdn/$name',
      contentType: type,
      sizeBytes: 3,
      uploadedBy: 'u',
      createdAt: '',
      noSave: noSave,
    );

ChatMessage msg(
  String id,
  String conversationId,
  int minute, {
  bool sealed = false,
  bool privateChat = false,
  List<ChatMessageAttachment> attachments = const [],
}) => ChatMessage(
  id: id,
  conversationId: conversationId,
  userId: 'peer',
  body: sealed ? '' : 'plain $id',
  createdAt: DateTime.utc(2026, 9, 27, 10, minute).toIso8601String(),
  privateChat: privateChat,
  attachments: attachments,
  encryptedBody: sealed ? 'CIPHER' : null,
  encryptionNonce: sealed ? 'NONCE' : null,
  encryptionVersion: sealed ? 1 : null,
  encryptionKeyVersion: sealed ? 1 : null,
);

void main() {
  late Directory dir;
  final key = List<int>.generate(32, (i) => i * 3);

  setUp(() => dir = Directory.systemTemp.createTempSync('backup_round_trip'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('backs up what was chosen and restores it, text and photo', () async {
    final photo = File('${dir.path}/photo.jpg')..writeAsBytesSync([1, 2, 3]);
    final video = File('${dir.path}/clip.mp4')..writeAsBytesSync([4, 5, 6]);
    final store = [
      msg('g1', 'group', 1, attachments: [att('photo.jpg', 'image/jpeg')]),
      msg('d1', 'dm', 2, sealed: true),
      msg('d2', 'dm', 3, sealed: true), // this phone cannot open it
      msg('d3', 'dm', 4, attachments: [att('clip.mp4', 'video/mp4')]),
      msg(
        'd4',
        'dm',
        5,
        attachments: [att('secret.jpg', 'image/jpeg', noSave: true)],
      ),
      msg('p1', 'private', 6),
      msg('x1', 'dm', 7, privateChat: true),
      msg('gone', 'deleted', 8),
    ];
    final file = File('${dir.path}/b.abxbackup');
    final writer = await BackupFileWriter.create(
      file,
      accountKey: key,
      userId: 'me',
      createdAtMs: 1,
    );
    var reads = 0;
    final stats = await BackupExporter(
      readPage: (afterMs, afterId) async => reads++ == 0 ? store : const [],
      allows: (m) => m.conversationId != 'deleted',
      openBody: (m) async => m.id == 'd1' ? 'hello from d1' : null,
      localFile: (url) async => switch (url) {
        'https://cdn/photo.jpg' => photo,
        'https://cdn/clip.mp4' => video,
        _ => null,
      },
      choices: const BackupChoices(),
      conversations: {
        'dm': conv('dm', 'dm'),
        'group': conv('group', 'group'),
        'private': conv('private', 'dm', privateChat: true),
      },
    ).run(writer);
    await writer.close();
    expect(stats.messages, 5);
    expect(stats.files, 1);
    expect(stats.unreadable, 1);

    final saved = <ChatMessage>[];
    final bodies = <String, String>{};
    final adopted = <String, List<int>>{};
    final restored = await BackupImporter(
      saveMessages: (m) async => saved.addAll(m),
      saveBodies: (b) async => bodies.addAll(b),
      adoptFile:
          ({
            required fileUrl,
            required fileName,
            required contentType,
            required source,
          }) async => adopted[fileUrl] = source.readAsBytesSync(),
      tempDir: Directory('${dir.path}/restore-tmp'),
    ).run(file, key);

    expect(saved.map((m) => m.id), ['g1', 'd1', 'd2', 'd3', 'd4']);
    // The sealed row comes back as the server serves it, never as plaintext.
    final d1 = saved.firstWhere((m) => m.id == 'd1');
    expect(d1.isEncrypted, isTrue);
    expect(d1.body, isEmpty);
    expect(bodies, {'d1': 'hello from d1'});
    // Photos by default; videos off; no-save never.
    expect(adopted.keys, ['https://cdn/photo.jpg']);
    expect(adopted['https://cdn/photo.jpg'], [1, 2, 3]);
    // The row keeps its attachments, so a skipped video can still be fetched.
    expect(saved.firstWhere((m) => m.id == 'd3').attachments, hasLength(1));
    expect(restored.messages, 5);
    expect(restored.files, 1);
  });

  test('groups off and DMs off each leave the other kind out', () async {
    final store = [msg('g1', 'group', 1), msg('d1', 'dm', 2)];
    Future<List<String>> run(BackupChoices choices) async {
      final file = File('${dir.path}/c.abxbackup');
      final writer = await BackupFileWriter.create(
        file,
        accountKey: key,
        userId: 'me',
        createdAtMs: 1,
      );
      var reads = 0;
      await BackupExporter(
        readPage: (a, b) async => reads++ == 0 ? store : const [],
        allows: (_) => true,
        openBody: (_) async => null,
        localFile: (_) async => null,
        choices: choices,
        conversations: {
          'dm': conv('dm', 'dm'),
          'group': conv('group', 'group'),
        },
      ).run(writer);
      await writer.close();
      final saved = <String>[];
      await BackupImporter(
        saveMessages: (m) async => saved.addAll(m.map((e) => e.id)),
        saveBodies: (_) async {},
        adoptFile:
            ({
              required fileUrl,
              required fileName,
              required contentType,
              required source,
            }) async {},
        tempDir: Directory('${dir.path}/t'),
      ).run(file, key);
      return saved;
    }

    expect(await run(const BackupChoices(groups: false)), ['d1']);
    expect(await run(const BackupChoices(directMessages: false)), ['g1']);
  });
}
