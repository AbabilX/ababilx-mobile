import 'dart:async';
import 'dart:io';

import 'client/share_client.dart';
import 'client/share_endpoint.dart';
import 'protocol/share_envelope.dart';
import 'protocol/share_file.dart';
import 'share_progress.dart';
import 'share_source.dart';
import 'store/share_records.dart';
import 'store/share_store.dart';

export 'share_source.dart';

/// Stores an outgoing message and keeps trying until it is over the wire.
///
/// A retry costs only the bytes still missing — the receiver answers every
/// attempt with what it already holds — so a drop mid-file is retried a few
/// times before the bubble is marked failed.
class ShareSender {
  ShareSender({
    required this.store,
    required this.client,
    required this.progress,
    required this.endpoint,
    this.onChanged,
    this.attempts = 4,
  });

  final ShareStore store;
  final ShareClient client;
  final ShareProgressHub progress;

  /// Where the device is NOW, or null when it is not on the network. Asked
  /// before every attempt: an address can change between two of them.
  final Future<ShareEndpoint?> Function(String deviceId) endpoint;
  final void Function(String deviceId, String messageId)? onChanged;
  final int attempts;

  final _cancels = <String, ShareCancel>{};

  bool sending(String messageId) => _cancels.containsKey(messageId);

  /// Writes the bubble, then sends it. Completes when the send is settled.
  Future<ShareSendOutcome> send(
    String deviceId,
    ShareEnvelope envelope,
    List<ShareSource> sources,
  ) async {
    await store.insertMessage(
      ShareMessageRecord(
        id: envelope.id,
        deviceId: deviceId,
        fromMe: true,
        kind: envelope.kind,
        sentAt: envelope.sentAt,
        status: ShareMessageStatus.sending,
        text: envelope.text,
        folderName: envelope.folderName,
      ),
      [
        for (final s in sources)
          ShareFileRecord(
            id: s.file.id,
            messageId: envelope.id,
            name: s.file.name,
            size: s.file.size,
            mime: s.file.mime,
            localPath: s.path,
            relPath: s.file.relPath,
            width: s.file.width,
            height: s.file.height,
            durationMs: s.file.durationMs,
            owned: s.owned,
          ),
      ],
    );
    onChanged?.call(deviceId, envelope.id);
    return _run(deviceId, envelope, {
      for (final s in sources) s.file.id: s.path,
    });
  }

  /// Retry on a failed bubble.
  Future<ShareSendOutcome> retry(String messageId) async {
    final message = await store.message(messageId);
    if (message == null || !message.fromMe || sending(messageId)) {
      return ShareSendOutcome.incomplete;
    }
    final files = await store.filesOf(messageId);
    await store.setMessageStatus(messageId, ShareMessageStatus.sending);
    onChanged?.call(message.deviceId, messageId);
    return _run(
      message.deviceId,
      ShareEnvelope(
        id: message.id,
        kind: message.kind,
        sentAt: message.sentAt,
        text: message.text,
        folderName: message.folderName,
        files: [
          for (final f in files)
            ShareFile(
              id: f.id,
              name: f.name,
              size: f.size,
              mime: f.mime,
              relPath: f.relPath,
              width: f.width,
              height: f.height,
              durationMs: f.durationMs,
            ),
        ],
      ),
      {for (final f in files) f.id: f.localPath},
    );
  }

  /// Stops a send and tells the receiver to drop what it has of it.
  Future<void> cancel(String messageId) async {
    _cancels[messageId]?.cancel();
    final message = await store.message(messageId);
    if (message == null) return;
    final to = await endpoint(message.deviceId);
    if (to != null) await client.cancel(to, messageId);
  }

  /// Delivers a delete-for-both. False when the device is not reachable; the
  /// caller keeps the request and tries again when it reappears.
  Future<bool> sendDelete(String deviceId, ShareEnvelope envelope) async {
    final to = await endpoint(deviceId);
    if (to == null) return false;
    final result = await client.send(to, envelope, const {});
    return result.outcome == ShareSendOutcome.done;
  }

  Future<ShareSendOutcome> _run(
    String deviceId,
    ShareEnvelope envelope,
    Map<String, String> paths,
  ) async {
    final cancel = _cancels[envelope.id] = ShareCancel();
    var outcome = ShareSendOutcome.unreachable;
    try {
      for (var attempt = 0; attempt < attempts; attempt++) {
        if (attempt > 0) {
          await Future<void>.delayed(Duration(seconds: 1 << (attempt - 1)));
        }
        if (cancel.canceled) {
          outcome = ShareSendOutcome.canceled;
          break;
        }
        final to = await endpoint(deviceId);
        if (to == null) {
          outcome = ShareSendOutcome.unreachable;
          continue;
        }
        final result = await client.send(to, envelope, paths, cancel: cancel);
        outcome = result.outcome;
        for (final file in envelope.files) {
          if (result.doneFileIds.contains(file.id)) {
            await store.setFileState(
              envelope.id,
              file.id,
              bytesDone: file.size,
              status: ShareFileStatus.done,
            );
          }
        }
        final again =
            outcome == ShareSendOutcome.unreachable ||
            (outcome == ShareSendOutcome.incomplete && !await _lost(paths));
        if (!again) break;
      }
    } finally {
      _cancels.remove(envelope.id);
    }
    await store.setMessageStatus(envelope.id, switch (outcome) {
      ShareSendOutcome.done => ShareMessageStatus.done,
      ShareSendOutcome.canceled => ShareMessageStatus.canceled,
      _ => ShareMessageStatus.failed,
    });
    progress.finish(envelope.id);
    onChanged?.call(deviceId, envelope.id);
    return outcome;
  }

  /// A source file that is gone will not come back on the next attempt.
  Future<bool> _lost(Map<String, String> paths) async {
    for (final path in paths.values) {
      if (!await File(path).exists()) return true;
    }
    return false;
  }
}
