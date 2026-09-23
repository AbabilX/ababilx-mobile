import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../history_transfer_codec.dart';
import 'v2_plan.dart';

/// Where one v2 transfer keeps its outbound state.
///
/// ```
/// <app support>/history_transfer_v2/<transfer id>/
///   plan.json              the plan (no key)
///   b000000/000000.bin     sealed message chunks — byte-identical on retry
///   b000000/pages.json     sealed descriptor pages — immutable server-side
/// secure storage           the transfer key
/// ```
///
/// Message chunks are sealed once and kept: gzip output is not reproducible and
/// the server freezes an uploaded chunk, so a retry must send the same bytes.
/// Media is never copied here — the attachment files are the snapshot.
class V2Store {
  V2Store(this.directory, {V2KeyVault? keys})
    : _keys = keys ?? SecureV2KeyVault();

  final Directory directory;
  final V2KeyVault _keys;

  static Future<V2Store> open(String transferId) async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory('${root.path}/history_transfer_v2/$transferId');
    await dir.create(recursive: true);
    return V2Store(dir);
  }

  Future<void> writeKey(String id, List<int> key) =>
      _keys.write(id, HistoryTransferCodec.b64(key));

  Future<List<int>?> readKey(String id) async {
    final raw = await _keys.read(id);
    return raw == null ? null : HistoryTransferCodec.bytesFromB64(raw);
  }

  File get _planFile => File('${directory.path}/plan.json');

  Future<V2Plan?> readPlan() async {
    try {
      if (!await _planFile.exists()) return null;
      return V2Plan.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(await _planFile.readAsString()) as Map,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Written to a temporary file and renamed, so a crash mid-write leaves the
  /// previous plan rather than half of a new one.
  Future<void> writePlan(V2Plan plan) async {
    final temp = File('${_planFile.path}.tmp');
    await temp.writeAsString(jsonEncode(plan.toJson()), flush: true);
    await temp.rename(_planFile.path);
  }

  Directory batchDir(int batch) =>
      Directory('${directory.path}/b${batch.toString().padLeft(6, '0')}');

  File chunkFile(int batch, int index) =>
      File('${batchDir(batch).path}/${index.toString().padLeft(6, '0')}.bin');

  File pagesFile(int batch) => File('${batchDir(batch).path}/pages.json');

  Future<List<String>?> readPages(int batch) async {
    try {
      final file = pagesFile(batch);
      if (!await file.exists()) return null;
      return (jsonDecode(await file.readAsString()) as List).cast<String>();
    } catch (_) {
      return null;
    }
  }

  Future<void> writePages(int batch, List<String> pages) async {
    await batchDir(batch).create(recursive: true);
    final temp = File('${pagesFile(batch).path}.tmp');
    await temp.writeAsString(jsonEncode(pages), flush: true);
    await temp.rename(pagesFile(batch).path);
  }

  /// Frees a committed batch's sealed chunks early: the destination has them.
  Future<void> dropBatch(int batch) async {
    try {
      final dir = batchDir(batch);
      if (!await dir.exists()) return;
      await for (final entry in dir.list()) {
        if (entry.path.endsWith('.bin')) await entry.delete();
      }
    } catch (_) {}
  }

  /// Removes everything, key included. The phone keeps its history; this was
  /// only the outbound copy.
  Future<void> discard(String id) async {
    try {
      await _keys.delete(id);
    } catch (_) {}
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } catch (_) {}
  }
}

/// Where the transfer key is kept between runs. Secure storage in the app —
/// the key seals a relay of history already on this device, but it must not
/// sit in a plain file next to the chunks it opens.
abstract class V2KeyVault {
  Future<String?> read(String transferId);
  Future<void> write(String transferId, String value);
  Future<void> delete(String transferId);
}

class SecureV2KeyVault implements V2KeyVault {
  SecureV2KeyVault([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _name(String id) => 'history_transfer_v2_key_$id';

  @override
  Future<String?> read(String transferId) =>
      _storage.read(key: _name(transferId));

  @override
  Future<void> write(String transferId, String value) =>
      _storage.write(key: _name(transferId), value: value);

  @override
  Future<void> delete(String transferId) =>
      _storage.delete(key: _name(transferId));
}
