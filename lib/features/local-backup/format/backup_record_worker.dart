import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'backup_crypto.dart';
import 'backup_errors.dart';
import 'backup_header.dart';

/// Seals and opens backup records on a background isolate.
///
/// On the UI isolate `cryptography_flutter` runs AES-GCM in Java over a
/// platform channel, handled on Android's main thread: every 512 KB record of
/// a backup or a restore copied twice and encrypted there, and the screen
/// froze for the whole run (a restore of 422 files took 100 s of dropped
/// frames). A spawned isolate has no plugin registered, so the same AES-GCM
/// runs in Dart on another core. Output is byte-identical — it is the same
/// algorithm, and the reader does not care which side sealed a record.
///
/// gzip goes with it: a 256 KB frames record was a synchronous encode on the
/// UI isolate too.
abstract final class BackupRecordWorker {
  /// `seal(type | body)`, with [body] gzipped first when it is a frames record.
  static Future<Uint8List> seal(
    List<int> key,
    List<int> aad,
    int type,
    List<int> body,
  ) {
    final keyBytes = Uint8List.fromList(key);
    final aadBytes = Uint8List.fromList(aad);
    final bodyBytes = body is Uint8List ? body : Uint8List.fromList(body);
    return Isolate.run(() async {
      final payload = type == BackupRecordType.frames
          ? gzip.encode(bodyBytes)
          : bodyBytes;
      final plain = Uint8List(payload.length + 1)
        ..[0] = type
        ..setRange(1, payload.length + 1, payload);
      return BackupCrypto.seal(SecretKey(keyBytes), aadBytes, plain);
    }, debugName: 'backup-seal');
  }

  /// The record's type and body, a frames body already gunzipped. A record
  /// that does not open (changed byte, wrong position, wrong key) or is
  /// empty is [BackupDamagedError].
  static Future<(int, Uint8List)> open(
    List<int> key,
    List<int> aad,
    List<int> sealed,
  ) async {
    final keyBytes = Uint8List.fromList(key);
    final aadBytes = Uint8List.fromList(aad);
    final sealedBytes = sealed is Uint8List
        ? sealed
        : Uint8List.fromList(sealed);
    // Errors are answered as null: an exception object crossing the isolate
    // boundary may arrive as a RemoteError, which no caller would recognise.
    final out = await Isolate.run(() async {
      try {
        final plain = await BackupCrypto.open(
          SecretKey(keyBytes),
          aadBytes,
          sealedBytes,
        );
        if (plain.isEmpty) return null;
        final type = plain[0];
        final body = Uint8List.sublistView(Uint8List.fromList(plain), 1);
        if (type != BackupRecordType.frames) return (type, body);
        return (type, Uint8List.fromList(gzip.decode(body)));
      } on SecretBoxAuthenticationError {
        return null;
      } on FormatException {
        // A frames record whose tag held but whose gzip does not.
        return null;
      }
    }, debugName: 'backup-open');
    if (out == null) throw const BackupDamagedError();
    return out;
  }
}
