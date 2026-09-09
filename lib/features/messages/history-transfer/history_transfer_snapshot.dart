import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'history_transfer_codec.dart';
import 'history_transfer_manifest.dart';

/// The on-disk snapshot one transfer is uploaded from.
///
/// **Why a snapshot at all, when the messages are already on this device:** a
/// chunk the server has accepted is frozen, and gzip output is not
/// reproducible, so re-running the export after an interruption would produce
/// different bytes for an index the destination may already have read. Sealing
/// the message stream into files first makes the upload resumable at chunk
/// granularity: the bytes for index k exist, and a resumed run sends exactly
/// those. Media needs no copy — the attachment files are the snapshot.
class HistoryTransferSnapshot {
  HistoryTransferSnapshot(this.directory);

  final Directory directory;

  static Future<HistoryTransferSnapshot> open(String transferId) async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory('${root.path}/history_transfer/$transferId');
    await dir.create(recursive: true);
    return HistoryTransferSnapshot(dir);
  }

  File messageChunk(int index) =>
      File('${directory.path}/m${index.toString().padLeft(6, '0')}.bin');

  File get planFile => File('${directory.path}/plan.json');

  Future<HistoryTransferPlan?> readPlan() async {
    try {
      if (!await planFile.exists()) return null;
      return HistoryTransferPlan.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(await planFile.readAsString()) as Map,
        ),
      );
    } catch (_) {
      // An unreadable plan is a snapshot to start over, not a crash: nothing
      // has been uploaded that a fresh plan could contradict, because the
      // plan is written before the first upload.
      return null;
    }
  }

  Future<void> writePlan(HistoryTransferPlan plan) =>
      planFile.writeAsString(jsonEncode(plan.toJson()), flush: true);

  /// Removes the snapshot. Called when the transfer completes or is cancelled
  /// — the phone keeps its history, and this was only ever the outbound copy.
  Future<void> discard() async {
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } catch (_) {}
  }
}

/// Everything a resumed run needs: the key, the chunk layout, and how far the
/// upload got.
///
/// The transfer key is written to app-private storage on purpose. It seals a
/// temporary relay of history whose plaintext is already sitting on this
/// device, so storing it here gives an attacker with the phone nothing they
/// did not already have — and without it a resumed run could not seal the
/// media chunks it has not sent yet. It goes when the snapshot goes.
class HistoryTransferPlan {
  HistoryTransferPlan({
    required this.transferId,
    required this.transferKey,
    required this.createdAtMs,
    required this.deviceId,
    required this.messageChunkCount,
    required this.messageCount,
    required this.conversationCount,
    required this.files,
    this.uploadedThrough = -1,
  });

  final String transferId;
  final List<int> transferKey;
  final int createdAtMs;
  final String deviceId;
  final int messageChunkCount;
  final int messageCount;
  final int conversationCount;
  final List<HistoryTransferPlannedFile> files;

  /// The highest index confirmed by the server. Resume starts at the next one;
  /// the server's own "already uploaded" answer is what settles a disagreement.
  int uploadedThrough;

  int get totalChunks =>
      messageChunkCount +
      files.fold<int>(0, (sum, file) => sum + file.chunkCount);

  Map<String, dynamic> toJson() => {
    'transfer_id': transferId,
    'key': HistoryTransferCodec.b64(transferKey),
    'created_at_ms': createdAtMs,
    'device_id': deviceId,
    'message_chunks': messageChunkCount,
    'messages': messageCount,
    'conversations': conversationCount,
    'uploaded_through': uploadedThrough,
    'files': files.map((file) => file.toJson()).toList(),
  };

  factory HistoryTransferPlan.fromJson(Map<String, dynamic> json) =>
      HistoryTransferPlan(
        transferId: json['transfer_id'] as String? ?? '',
        transferKey: HistoryTransferCodec.bytesFromB64(json['key'] as String),
        createdAtMs: (json['created_at_ms'] as num?)?.toInt() ?? 0,
        deviceId: json['device_id'] as String? ?? '',
        messageChunkCount: (json['message_chunks'] as num?)?.toInt() ?? 0,
        messageCount: (json['messages'] as num?)?.toInt() ?? 0,
        conversationCount: (json['conversations'] as num?)?.toInt() ?? 0,
        uploadedThrough: (json['uploaded_through'] as num?)?.toInt() ?? -1,
        files: (json['files'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map(
              (raw) => HistoryTransferPlannedFile.fromJson(
                Map<String, dynamic>.from(raw),
              ),
            )
            .toList(),
      );
}

/// One attachment and where its bytes sit in the index space.
class HistoryTransferPlannedFile {
  const HistoryTransferPlannedFile({
    required this.file,
    required this.localPath,
  });

  final HistoryTransferFile file;

  /// Empty when the phone does not hold the bytes. The manifest entry still
  /// goes, with no chunk range, so the destination shows the attachment as
  /// unavailable instead of as a download that will never arrive.
  final String localPath;

  int get chunkCount => file.chunkCount;

  Map<String, dynamic> toJson() => {...file.toJson(), 'local_path': localPath};

  factory HistoryTransferPlannedFile.fromJson(Map<String, dynamic> json) =>
      HistoryTransferPlannedFile(
        file: HistoryTransferFile.fromJson(json),
        localPath: json['local_path'] as String? ?? '',
      );
}
