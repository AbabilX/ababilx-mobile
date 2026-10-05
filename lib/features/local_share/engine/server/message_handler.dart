import 'dart:io';

import '../protocol/share_envelope.dart';
import '../protocol/share_routes.dart';
import '../share_layout.dart';
import '../store/share_records.dart';
import 'share_http.dart';
import 'share_server_context.dart';

/// `POST /abx/v1/messages` — stores the envelope and answers with how many
/// bytes of each file are already here. Posting a known id again changes
/// nothing; that answer is how a dropped transfer resumes.
Future<void> handleShareMessage(
  ShareServerContext ctx,
  HttpRequest request,
  ShareDeviceRecord device,
) async {
  final envelope = ShareEnvelope.fromJson(
    await readShareJson(request, ShareLimits.envelopeBodyBytes),
  );
  if (envelope == null) {
    return replyShareError(request, HttpStatus.badRequest, 'bad_envelope');
  }
  if (envelope.kind == ShareKind.delete) {
    await _applyDelete(ctx, device, envelope.targetId!);
    return replyShare(request, HttpStatus.ok, {'upload': <String, int>{}});
  }

  final existing = await ctx.store.message(envelope.id);
  if (existing != null) {
    if (existing.deviceId != device.deviceId || existing.fromMe) {
      return replyShareError(request, HttpStatus.conflict, 'id_taken');
    }
    if (existing.status == ShareMessageStatus.canceled) {
      return replyShareError(request, HttpStatus.gone, 'canceled');
    }
  } else {
    await _insert(ctx, device, envelope);
    ctx.onMessage?.call(device.deviceId, envelope.id);
  }

  final offsets = <String, int>{};
  for (final file in await ctx.store.filesOf(envelope.id)) {
    offsets[file.id] = file.done ? file.size : await _partLength(file);
  }
  await replyShare(request, HttpStatus.ok, {'upload': offsets});
}

/// `POST /abx/v1/messages/<id>/cancel`.
Future<void> handleShareCancel(
  ShareServerContext ctx,
  HttpRequest request,
  ShareDeviceRecord device,
  String messageId,
) async {
  final message = await ctx.store.message(messageId);
  if (message != null &&
      message.deviceId == device.deviceId &&
      !message.fromMe &&
      message.status == ShareMessageStatus.receiving) {
    await ctx.store.setMessageStatus(messageId, ShareMessageStatus.canceled);
    for (final file in await ctx.store.filesOf(messageId)) {
      if (!file.done) await _deleteQuietly(sharePartPath(file.localPath));
    }
    ctx.progress.finish(messageId);
    ctx.onMessage?.call(device.deviceId, messageId);
  }
  await replyShare(request, HttpStatus.ok);
}

Future<void> _insert(
  ShareServerContext ctx,
  ShareDeviceRecord device,
  ShareEnvelope envelope,
) async {
  final paths = ctx.layout.pathsFor(
    device.deviceId,
    envelope.id,
    envelope.files,
  );
  final rows = <ShareFileRecord>[];
  for (var i = 0; i < envelope.files.length; i++) {
    final file = envelope.files[i];
    // An empty file has no bytes to wait for.
    if (file.size == 0) await File(paths[i]).create(recursive: true);
    rows.add(
      ShareFileRecord(
        id: file.id,
        messageId: envelope.id,
        name: file.name,
        size: file.size,
        mime: file.mime,
        localPath: paths[i],
        relPath: file.relPath,
        width: file.width,
        height: file.height,
        durationMs: file.durationMs,
        status: file.size == 0 ? ShareFileStatus.done : ShareFileStatus.pending,
      ),
    );
  }
  await ctx.store.insertMessage(
    ShareMessageRecord(
      id: envelope.id,
      deviceId: device.deviceId,
      fromMe: false,
      kind: envelope.kind,
      sentAt: envelope.sentAt,
      status: rows.every((f) => f.done)
          ? ShareMessageStatus.done
          : ShareMessageStatus.receiving,
      text: envelope.text,
      folderName: envelope.folderName,
      unread: true,
    ),
    rows,
  );
}

/// Only a message the CALLER wrote, in the caller's own thread.
Future<void> _applyDelete(
  ShareServerContext ctx,
  ShareDeviceRecord device,
  String targetId,
) async {
  final target = await ctx.store.message(targetId);
  if (target == null || target.deviceId != device.deviceId || target.fromMe) {
    return;
  }
  for (final file in await ctx.store.deleteMessage(targetId)) {
    await _deleteQuietly(file.localPath);
    await _deleteQuietly(sharePartPath(file.localPath));
  }
  await _deleteQuietly(
    ctx.layout.messageDir(device.deviceId, targetId),
    directory: true,
  );
  ctx.progress.finish(targetId);
  ctx.onDeleted?.call(device.deviceId, targetId);
}

Future<int> _partLength(ShareFileRecord file) async {
  final part = File(sharePartPath(file.localPath));
  return await part.exists() ? await part.length() : 0;
}

Future<void> _deleteQuietly(String path, {bool directory = false}) async {
  try {
    final entity = directory ? Directory(path) : File(path);
    if (await entity.exists()) await entity.delete(recursive: directory);
  } catch (_) {}
}
