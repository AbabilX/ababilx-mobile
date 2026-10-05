import 'dart:io';

import '../protocol/share_routes.dart';
import '../share_layout.dart';
import '../store/share_records.dart';
import 'share_http.dart';
import 'share_server_context.dart';

class _TooManyBytes implements Exception {}

/// `PUT /abx/v1/files/<message>/<file>?offset=N` — appends the body to the
/// file's `.part` and renames it into place once every byte is here.
///
/// The body is piped with `addStream`, so a slow disk slows the sender down
/// instead of filling memory, and what has arrived stays on disk when the
/// connection drops: the next attempt starts from that byte.
Future<void> handleShareFile(
  ShareServerContext ctx,
  HttpRequest request,
  ShareDeviceRecord device,
  String messageId,
  String fileId,
) async {
  final message = await ctx.store.message(messageId);
  final file = await ctx.store.file(messageId, fileId);
  if (message == null ||
      file == null ||
      message.fromMe ||
      message.deviceId != device.deviceId) {
    return replyShareError(request, HttpStatus.notFound, 'not_found');
  }
  if (message.status == ShareMessageStatus.canceled) {
    return replyShareError(request, HttpStatus.gone, 'canceled');
  }
  if (file.done) {
    return replyShare(request, HttpStatus.ok, {'received': file.size});
  }

  final key = '$messageId/$fileId';
  if (!ctx.activeFiles.add(key)) {
    return replyShareError(request, HttpStatus.tooManyRequests, 'busy');
  }
  try {
    await _receive(ctx, request, device, file);
  } finally {
    ctx.activeFiles.remove(key);
  }
}

Future<void> _receive(
  ShareServerContext ctx,
  HttpRequest request,
  ShareDeviceRecord device,
  ShareFileRecord file,
) async {
  final part = File(sharePartPath(file.localPath));
  await part.parent.create(recursive: true);
  final have = await part.exists() ? await part.length() : 0;
  final offset = int.tryParse(request.uri.queryParameters['offset'] ?? '');
  if (offset != have) {
    return replyShare(request, HttpStatus.conflict, {'offset': have});
  }

  var total = have;
  var overflow = false;
  final sink = part.openWrite(mode: FileMode.append);
  try {
    await sink.addStream(
      request.timeout(ShareLimits.idleTimeout).map((chunk) {
        total += chunk.length;
        if (total > file.size) throw _TooManyBytes();
        ctx.progress.report(file.messageId, file.id, total);
        return chunk;
      }),
    );
  } on _TooManyBytes {
    overflow = true;
  } catch (_) {
    // Dropped or idle: keep what arrived.
  }
  try {
    await sink.close();
  } catch (_) {}

  if (overflow) {
    await _fail(ctx, device, file, part);
    return replyShareError(request, HttpStatus.badRequest, 'too_many_bytes');
  }

  final written = await part.exists() ? await part.length() : 0;
  if (written != file.size) {
    await ctx.store.setFileState(
      file.messageId,
      file.id,
      bytesDone: written,
      status: ShareFileStatus.pending,
    );
    return replyShare(request, HttpStatus.badRequest, {'offset': written});
  }

  await part.rename(file.localPath);
  await ctx.store.setFileState(
    file.messageId,
    file.id,
    bytesDone: file.size,
    status: ShareFileStatus.done,
  );
  final files = await ctx.store.filesOf(file.messageId);
  if (files.every((f) => f.done)) {
    await ctx.store.setMessageStatus(file.messageId, ShareMessageStatus.done);
    ctx.progress.finish(file.messageId);
  }
  ctx.onMessage?.call(device.deviceId, file.messageId);
  await replyShare(request, HttpStatus.ok, {'received': file.size});
}

Future<void> _fail(
  ShareServerContext ctx,
  ShareDeviceRecord device,
  ShareFileRecord file,
  File part,
) async {
  try {
    if (await part.exists()) await part.delete();
  } catch (_) {}
  await ctx.store.setFileState(
    file.messageId,
    file.id,
    bytesDone: 0,
    status: ShareFileStatus.failed,
  );
  await ctx.store.setMessageStatus(file.messageId, ShareMessageStatus.failed);
  ctx.progress.finish(file.messageId);
  ctx.onMessage?.call(device.deviceId, file.messageId);
}
