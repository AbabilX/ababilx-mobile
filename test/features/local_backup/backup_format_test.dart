import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ababilx/features/local-backup/format/backup_crypto.dart';
import 'package:ababilx/features/local-backup/format/backup_errors.dart';
import 'package:ababilx/features/local-backup/format/backup_file_reader.dart';
import 'package:ababilx/features/local-backup/format/backup_file_writer.dart';
import 'package:ababilx/features/local-backup/format/backup_header.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemorySink implements BackupFileSink {
  final bytes = BytesBuilder();
  bool closed = false;
  @override
  Future<void> add(List<int> b) async => bytes.add(b);
  @override
  Future<void> close() async => closed = true;
}

void main() {
  late Directory dir;
  final key = List<int>.generate(32, (i) => i);
  final otherKey = List<int>.generate(32, (i) => 255 - i);

  setUp(() => dir = Directory.systemTemp.createTempSync('backup_format'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<File> write({int messages = 3, List<int>? media}) async {
    final file = File('${dir.path}/b.abxbackup');
    final writer = await BackupFileWriter.create(
      file,
      accountKey: key,
      userId: 'user-1',
      createdAtMs: 1000,
    );
    for (var i = 0; i < messages; i++) {
      await writer.addFrame({
        't': 'msg',
        'm': {'id': 'm$i'},
        'p': 'secret $i',
      });
    }
    if (media != null) {
      final source = File('${dir.path}/photo.jpg')..writeAsBytesSync(media);
      await writer.addFile({'u': 'https://cdn/x.jpg', 'n': 'x.jpg'}, source);
    }
    await writer.addFrame({
      't': 'msg',
      'm': {'id': 'last'},
    });
    await writer.close();
    return file;
  }

  test('round-trips frames and a multi-part file in order', () async {
    final media = List<int>.generate(
      BackupFileWriter.filePartBytes * 2 + 17,
      (i) => i % 251,
    );
    final file = await write(media: media);
    final frames = <Map<String, dynamic>>[];
    final sink = _MemorySink();
    await BackupFileReader(file, key).run(
      onFrame: (f) async => frames.add(f),
      onFile: (f) async {
        expect(f['u'], 'https://cdn/x.jpg');
        expect(f['s'], media.length);
        return sink;
      },
    );
    expect(frames.map((f) => f['m']['id']), ['m0', 'm1', 'm2', 'last']);
    expect(frames.first['p'], 'secret 0');
    expect(sink.closed, isTrue);
    expect(sink.bytes.takeBytes(), media);
  });

  test('nothing readable reaches the disk', () async {
    final bytes = (await write()).readAsBytesSync();
    expect(utf8.decode(bytes, allowMalformed: true), isNot(contains('secret')));
  });

  test('the clear header names the account and time, nothing else', () async {
    final header = await BackupFileReader.readHeader(await write());
    expect(header.userId, 'user-1');
    expect(header.createdAtMs, 1000);
  });

  test('another account key is refused as wrong account, not damage', () {
    expect(
      () async => BackupFileReader(
        await write(),
        otherKey,
      ).run(onFrame: (_) async {}, onFile: (_) async => null),
      throwsA(isA<BackupWrongAccountError>()),
    );
  });

  test('a file cut short is refused as incomplete', () async {
    final file = await write(messages: 1);
    final bytes = file.readAsBytesSync();
    file.writeAsBytesSync(bytes.sublist(0, bytes.length - 20));
    expect(
      () => BackupFileReader(
        file,
        key,
      ).run(onFrame: (_) async {}, onFile: (_) async => null),
      throwsA(isA<BackupIncompleteError>()),
    );
  });

  test(
    'a changed byte fails the record, and so does an edited header',
    () async {
      final file = await write(messages: 1);
      final bytes = file.readAsBytesSync();
      bytes[bytes.length - 30] ^= 1;
      file.writeAsBytesSync(bytes);
      await expectLater(
        BackupFileReader(
          file,
          key,
        ).run(onFrame: (_) async {}, onFile: (_) async => null),
        throwsA(isA<BackupDamagedError>()),
      );

      final clean = await write(messages: 1);
      final text = clean.readAsBytesSync();
      final at = _indexOf(text, utf8.encode('"created_at_ms":1000'));
      text[at + '"created_at_ms":'.length] = '2'.codeUnitAt(0);
      clean.writeAsBytesSync(text);
      await expectLater(
        BackupFileReader(
          clean,
          key,
        ).run(onFrame: (_) async {}, onFile: (_) async => null),
        throwsA(isA<BackupDamagedError>()),
      );
    },
  );

  test('a stranger file is not a backup', () async {
    final file = File('${dir.path}/x')..writeAsStringSync('hello world');
    expect(
      () => BackupFileReader.readHeader(file),
      throwsA(isA<BackupNotABackupError>()),
    );
  });

  test(
    'the zero salt equals an empty one, so no HKDF key is ever empty',
    () async {
      // Java's HMAC (cryptography_flutter on a phone) rejects an empty key, so
      // BackupCrypto never passes one; HMAC zero-pads, so nothing changes.
      Future<List<int>> derive(List<int> salt) async =>
          (await Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
            secretKey: SecretKey(key),
            nonce: salt,
            info: utf8.encode(BackupCrypto.checkInfo),
          )).extractBytes();
      expect(BackupCrypto.noSalt, hasLength(32));
      expect(await derive(BackupCrypto.noSalt), await derive(const []));
    },
  );

  test('format strings are pinned', () {
    expect(BackupFormat.magic, [0x41, 0x42, 0x58, 0x42, 0x41, 0x4B, 0, 1]);
    expect(
      utf8.decode(BackupCrypto.recordAad('d', 3)),
      'ababilx-local-backup-v1:d:3',
    );
    expect(BackupCrypto.fileInfo, 'ababilx-local-backup-file-v1');
    expect(BackupCrypto.checkInfo, 'ababilx-local-backup-check-v1');
    expect(BackupCrypto.restoredInfo, 'ababilx-restored-body-v1');
  });
}

int _indexOf(List<int> haystack, List<int> needle) {
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    var hit = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        hit = false;
        break;
      }
    }
    if (hit) return i;
  }
  return -1;
}
