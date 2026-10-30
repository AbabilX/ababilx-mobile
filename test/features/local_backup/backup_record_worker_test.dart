import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ababilx/features/local-backup/format/backup_crypto.dart';
import 'package:ababilx/features/local-backup/format/backup_errors.dart';
import 'package:ababilx/features/local-backup/format/backup_header.dart';
import 'package:ababilx/features/local-backup/format/backup_record_worker.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final key = List<int>.generate(32, (i) => i * 3 % 256);
  final aad = BackupCrypto.recordAad('digest', 7);
  final body = List<int>.generate(BackupFileWriterSizes.part + 9, (i) => i % 251);

  test('a record sealed off the UI isolate opens with the ordinary open', () async {
    final sealed = await BackupRecordWorker.seal(
      key,
      aad,
      BackupRecordType.filePart,
      body,
    );
    final plain = await BackupCrypto.open(SecretKey(key), aad, sealed);
    expect(plain.first, BackupRecordType.filePart);
    expect(plain.sublist(1), body);
  });

  test('a frames record is gzipped inside the worker', () async {
    final text = utf8.encode('{"t":"msg"}\n' * 400);
    final sealed = await BackupRecordWorker.seal(
      key,
      aad,
      BackupRecordType.frames,
      text,
    );
    final plain = await BackupCrypto.open(SecretKey(key), aad, sealed);
    expect(plain.first, BackupRecordType.frames);
    expect(gzip.decode(plain.sublist(1)), text);
  });

  test('open returns the type and the body, frames already gunzipped', () async {
    final text = utf8.encode('{"t":"conv"}\n' * 50);
    final sealed = await BackupRecordWorker.seal(
      key,
      aad,
      BackupRecordType.frames,
      text,
    );
    final (type, out) = await BackupRecordWorker.open(key, aad, sealed);
    expect(type, BackupRecordType.frames);
    expect(out, text);

    final part = await BackupRecordWorker.seal(
      key,
      aad,
      BackupRecordType.filePart,
      body,
    );
    final (partType, partBody) = await BackupRecordWorker.open(key, aad, part);
    expect(partType, BackupRecordType.filePart);
    expect(partBody, body);
  });

  test('a changed byte, a wrong position or a wrong key is damage', () async {
    final sealed = await BackupRecordWorker.seal(
      key,
      aad,
      BackupRecordType.filePart,
      body,
    );
    final flipped = Uint8List.fromList(sealed)..[40] ^= 1;
    await expectLater(
      BackupRecordWorker.open(key, aad, flipped),
      throwsA(isA<BackupDamagedError>()),
    );
    await expectLater(
      BackupRecordWorker.open(key, BackupCrypto.recordAad('digest', 8), sealed),
      throwsA(isA<BackupDamagedError>()),
    );
    await expectLater(
      BackupRecordWorker.open(List<int>.filled(32, 9), aad, sealed),
      throwsA(isA<BackupDamagedError>()),
    );
  });

  test('seal output is nonce | ciphertext | tag', () async {
    final sealed = await BackupCrypto.seal(SecretKey(key), aad, [1, 2, 3]);
    expect(
      sealed.length,
      BackupCrypto.nonceBytes + 3 + BackupCrypto.tagBytes,
    );
    expect(await BackupCrypto.open(SecretKey(key), aad, sealed), [1, 2, 3]);
  });
}

/// The writer's file-part size, without importing the writer for one number.
abstract final class BackupFileWriterSizes {
  static const part = 512 * 1024;
}
