import 'dart:convert';
import 'dart:typed_data';

import 'package:ababilx/features/messages/history-transfer/history_transfer_codec.dart';
import 'package:ababilx/features/messages/history-transfer/v2/v2_api.dart';
import 'package:ababilx/features/messages/history-transfer/v2/v2_crypto.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// The server's v2 rules, in memory, plus a destination that commits each
/// batch the moment it is finalized. Also opens what was sent, the way the
/// browser will, so the test asserts on the decrypted result.
class FakeRelay implements HistoryTransferV2Api {
  FakeRelay(this.transferId, this.key);

  final String transferId;
  final List<int> key;
  final Map<String, List<int>> objects = {};
  final Set<String> settled = {};
  final Set<String> settleOnReserve = {};
  final List<String> puts = [];
  final List<String> kinds = [];
  final List<bool> finals = [];
  final Map<int, String> status = {};
  final Map<int, List<String>> pages = {};
  final Map<int, int> chunkCounts = {};
  String? seal;
  int? sealLast;
  void Function()? beforeFirstMediaReserve;

  @override
  Future<Map<String, dynamic>> job(String id) async => {
    'live': true,
    'transfer': {'status': 'approved', 'dest_inventory_ciphertext': ''},
    'batches': [for (final e in status.entries) {'batch': e.key, 'status': e.value}],
  };

  @override
  Future<void> putInventory(String id, String ciphertext) async {}

  @override
  Future<void> createBatch(String id, int batch, String kind, bool isFinal) async {
    if (status.containsKey(batch)) return;
    expect(batch, status.length, reason: 'batches are created in order');
    expect(status.values.every((s) => s == 'committed'), isTrue);
    status[batch] = 'open';
    kinds.add(kind);
    finals.add(isFinal);
  }

  @override
  Future<({String url, bool uploaded})> reserve(String id, int batch, int index, int size) async {
    final name = '$batch/$index';
    if (kinds[batch] == 'media' && beforeFirstMediaReserve != null) {
      beforeFirstMediaReserve!();
      beforeFirstMediaReserve = null;
    }
    if (settleOnReserve.remove(name)) settled.add(name);
    return (url: 'obj://$name', uploaded: settled.contains(name));
  }

  @override
  Future<void> put(String url, List<int> bytes) async {
    final name = url.substring('obj://'.length);
    puts.add(name);
    objects[name] = bytes;
  }

  @override
  Future<void> confirm(String id, int batch, int index, String checksum) async {
    final name = '$batch/$index';
    expect(checksum, sha256.convert(objects[name]!).toString());
    settled.add(name);
  }

  @override
  Future<void> putPage(String id, int batch, int page, String ciphertext) async =>
      (pages[batch] ??= []).add(ciphertext);

  @override
  Future<void> finalize(String id, int batch, int chunks, int pageCount) async {
    for (var i = 0; i < chunks; i++) {
      expect(settled.contains('$batch/$i') || objects.containsKey('$batch/$i'), isTrue,
          reason: 'finalize only a gapless batch');
    }
    chunkCounts[batch] = chunks;
    status[batch] = 'committed';
  }

  @override
  Future<void> putSeal(String id, int lastBatch, String ciphertext) async {
    seal = ciphertext;
    sealLast = lastBatch;
  }

  Future<Uint8List> stream(int batch, String kind) async {
    final out = <int>[];
    for (var i = 0; i < chunkCounts[batch]!; i++) {
      out.addAll(await HistoryTransferV2Crypto.open(
        key, HistoryTransferV2Crypto.chunkAad(transferId, batch, kind, i), objects['$batch/$i']!,
      ));
    }
    return Uint8List.fromList(out);
  }

  Future<Map<String, dynamic>> descriptor(int batch) async {
    final sealedPages = pages[batch]!;
    final out = <int>[];
    for (var p = 0; p < sealedPages.length; p++) {
      out.addAll(await HistoryTransferV2Crypto.open(
        key,
        HistoryTransferV2Crypto.pageAad(transferId, batch, p, sealedPages.length),
        HistoryTransferCodec.bytesFromB64(sealedPages[p]),
      ));
    }
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(out)) as Map);
  }

  Future<Map<String, dynamic>> openSeal() async => Map<String, dynamic>.from(
    await HistoryTransferV2Crypto.openJson(key, HistoryTransferV2Crypto.sealAad(transferId), seal!)
        as Map,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}
