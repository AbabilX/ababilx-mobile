import 'dart:io';

import 'package:path/path.dart' as p;

import 'data/share_device_queries.dart';
import 'engine/client/share_endpoint.dart';
import 'engine/protocol/share_envelope.dart';
import 'engine/protocol/share_file.dart';
import 'engine/protocol/share_ids.dart';
import 'engine/share_layout.dart';
import 'engine/share_sender.dart';
import 'engine/store/share_records.dart';
import 'local_share_engine.dart';

/// A file the user chose to send.
class SharePick {
  const SharePick({
    required this.path,
    required this.name,
    required this.mime,
    this.owned = false,
    this.relPath,
    this.width,
    this.height,
    this.durationMs,
  });

  final String path;
  final String name;
  final String mime;

  /// True for a copy the app made (a picker's cache file, a recording): it
  /// is moved into the thread's folder and deleted with the bubble.
  final bool owned;
  final String? relPath;
  final int? width;
  final int? height;
  final int? durationMs;
}

int _now() => DateTime.now().millisecondsSinceEpoch;

/// What the thread screen does.
extension LocalShareActions on LocalShareEngine {
  Future<ShareSendOutcome> sendText(String peerId, String text) => sender.send(
    peerId,
    ShareEnvelope(
      id: newShareId(),
      kind: ShareKind.text,
      sentAt: _now(),
      text: text.trim(),
    ),
    const [],
  );

  /// Sends files as one bubble. [kind] is `files`, `voice` or `folder`.
  Future<ShareSendOutcome> sendFiles(
    String peerId,
    List<SharePick> picks, {
    ShareKind kind = ShareKind.files,
    String? caption,
    String? folderName,
  }) async {
    final id = newShareId();
    final sources = <ShareSource>[];
    for (final pick in picks) {
      final name = cleanShareFileName(pick.name) ?? 'file';
      final path = pick.owned
          ? await _adopt(peerId, id, pick.path, name, sources.length)
          : pick.path;
      final file = File(path);
      if (!await file.exists()) continue;
      sources.add(
        ShareSource(
          ShareFile(
            id: newShareId(),
            name: name,
            size: await file.length(),
            mime: pick.mime,
            relPath: kind == ShareKind.folder
                ? cleanShareRelPath(pick.relPath) ?? name
                : null,
            width: pick.width,
            height: pick.height,
            durationMs: pick.durationMs,
          ),
          path,
          owned: pick.owned,
        ),
      );
    }
    if (sources.isEmpty) return ShareSendOutcome.incomplete;
    return sender.send(
      peerId,
      ShareEnvelope(
        id: id,
        kind: kind,
        sentAt: _now(),
        text: caption,
        folderName: folderName,
        files: [for (final s in sources) s.file],
      ),
      sources,
    );
  }

  /// Moves an app-made copy beside the thread's other files, so a cache
  /// cleaner cannot take a sent bubble's file away.
  Future<String> _adopt(
    String peerId,
    String messageId,
    String path,
    String name,
    int index,
  ) async {
    final dir = Directory(p.join(layout.messageDir(peerId, messageId), 'out'));
    await dir.create(recursive: true);
    final target = p.join(dir.path, '${index}_$name');
    try {
      await File(path).rename(target);
    } on FileSystemException {
      await File(path).copy(target);
      try {
        await File(path).delete();
      } catch (_) {}
    }
    return target;
  }

  /// Removes a bubble from this device only.
  Future<void> deleteForMe(String messageId) async {
    final message = await store.message(messageId);
    if (message == null) return;
    if (sender.sending(messageId)) await sender.cancel(messageId);
    await _removeFiles(await store.deleteMessage(messageId));
    await _removeDir(layout.messageDir(message.deviceId, messageId));
    progress.finish(messageId);
  }

  /// Removes one of OUR bubbles here and asks the other device to do the
  /// same — at once if it is in range, the next time it appears if not.
  Future<void> deleteForBoth(String messageId) async {
    final message = await store.message(messageId);
    if (message == null || !message.fromMe) return;
    await deleteForMe(messageId);
    final opId = newShareId();
    await queries.queueDelete(opId, message.deviceId, messageId);
    await flushDeletes(message.deviceId);
  }

  /// Delivers the delete requests waiting for [peerId].
  Future<void> flushDeletes(String peerId) async {
    for (final op in await queries.pendingDeletes(peerId)) {
      final delivered = await sender.sendDelete(
        peerId,
        ShareEnvelope(
          id: op.id,
          kind: ShareKind.delete,
          sentAt: _now(),
          targetId: op.targetId,
        ),
      );
      if (!delivered) return;
      await queries.clearPendingDelete(op.id);
    }
  }

  /// Deletes the thread and stops trusting the device; it must ask again.
  Future<void> forgetDevice(String peerId) async {
    await _removeFiles(await queries.deleteThread(peerId));
    await _removeDir(layout.deviceDir(peerId));
  }

  /// Refuses every later request from [peerId]. History stays.
  Future<void> setBlocked(String peerId, bool blocked) =>
      queries.setBlocked(peerId, blocked);

  Future<void> _removeFiles(List<ShareFileRecord> files) async {
    for (final file in files) {
      if (!file.owned) continue;
      for (final path in [file.localPath, sharePartPath(file.localPath)]) {
        try {
          final f = File(path);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> _removeDir(String path) async {
    try {
      final dir = Directory(path);
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }
}
