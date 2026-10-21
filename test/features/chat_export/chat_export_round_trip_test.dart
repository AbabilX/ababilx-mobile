import 'dart:io';

import 'package:ababilx/features/chat-export/export/chat_export_staging.dart';
import 'package:ababilx/features/chat-export/export/chat_export_zip.dart';
import 'package:ababilx/features/chat-export/format/chat_export_format.dart';
import 'package:ababilx/features/chat-export/import/chat_import_store.dart';
import 'package:ababilx/features/chat-export/import/chat_import_unzip.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;

  setUp(() async => tmp = await Directory.systemTemp.createTemp('chatexp'));
  tearDown(() => tmp.delete(recursive: true));

  ExportedMessage msg(
    String id,
    String sender,
    String text, {
    files = const <ExportedFile>[],
  }) => ExportedMessage(
    id: id,
    at: '2026-10-21T10:00:0${id.length}Z',
    senderId: sender,
    sender: sender == 'me' ? 'Murad' : 'Alice',
    kind: 'text',
    text: text,
    files: files,
  );

  test('export zip imports back: chats, text, files', () async {
    final photo = File('${tmp.path}/src.jpg')..writeAsBytesSync([1, 2, 3, 4]);
    final staging = ChatExportStaging(Directory('${tmp.path}/stage'));
    await staging.open('c1', 'Alice', 'dm');
    await staging.open('c2', 'Team / ../x', 'group');
    final path = staging.reserveMedia(
      'c1',
      'https://cdn/a',
      'photo.jpg',
      photo.path,
    );
    // The same file in a second message goes in once.
    expect(
      staging.reserveMedia('c1', 'https://cdn/a', 'photo.jpg', photo.path),
      path,
    );
    await staging.add('c1', msg('m1', 'other', 'hello\nthere'));
    await staging.add(
      'c1',
      msg(
        'm22',
        'me',
        '',
        files: [
          ExportedFile(
            name: 'photo.jpg',
            type: 'image/jpeg',
            size: 4,
            path: path,
          ),
        ],
      ),
    );
    await staging.add('c2', msg('m3', 'other', 'group hi'));
    final (manifest, entries) = await staging.finish(
      accountId: 'me',
      accountName: 'Murad',
      at: DateTime.utc(2026, 10, 21),
    );
    expect(manifest.chats.map((c) => c.messages), [2, 1]);
    // A title cannot climb out of its folder.
    expect(manifest.chats[1].folder.contains('/'), isFalse);

    final zip = '${tmp.path}/out.zip';
    await writeChatExportZip(zip, entries);

    final out = Directory('${tmp.path}/imported')..createSync();
    final read = await unzipChatExport(zip, out.path);
    expect(read.accountId, 'me');
    expect(read.messages, 3);
    final chatDir = Directory('${out.path}/chats/${read.chats.first.folder}');
    final messages = await ChatImportStore.messages(chatDir);
    expect(messages.map((m) => m.text), ['hello\nthere', '']);
    final file = messages[1].files.single;
    expect(File('${chatDir.path}/${file.path}').readAsBytesSync(), [
      1,
      2,
      3,
      4,
    ]);
    final txt = File('${chatDir.path}/messages.txt').readAsStringSync();
    expect(txt, contains('Alice: hello'));
    expect(File('${out.path}/README.txt').existsSync(), isTrue);
  });

  test('a zip that is not an export is refused', () async {
    final zip = '${tmp.path}/other.zip';
    final enc = ZipFileEncoder()..create(zip);
    enc.addArchiveFile(ArchiveFile.string('hello.txt', 'hi'));
    await enc.close();
    expect(
      () => unzipChatExport(zip, tmp.path),
      throwsA(isA<ChatImportFailure>()),
    );
  });

  test('only export paths are unpacked', () {
    const folders = {'001-Alice'};
    expect(chatImportPathAllowed('chats.json', folders), isTrue);
    expect(
      chatImportPathAllowed('chats/001-Alice/messages.json', folders),
      isTrue,
    );
    expect(
      chatImportPathAllowed('chats/001-Alice/media/1-a.jpg', folders),
      isTrue,
    );
    expect(
      chatImportPathAllowed('chats/001-Alice/media/../../x', folders),
      isFalse,
    );
    expect(
      chatImportPathAllowed('chats/002-Bob/messages.json', folders),
      isFalse,
    );
    expect(chatImportPathAllowed('../evil', folders), isFalse);
    expect(chatImportPathAllowed('chats/001-Alice/run.sh', folders), isFalse);
  });

  test('names are safe and numbered', () {
    expect(ChatExportFormat.safeName('a/b\\c:d'), 'a_b_c_d');
    expect(ChatExportFormat.safeName('...'), 'file');
    expect(ChatExportFormat.chatFolder(7, 'আলিফ'), '007-আলিফ');
  });
}
