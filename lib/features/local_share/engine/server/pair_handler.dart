import 'dart:io';

import '../protocol/share_ids.dart';
import '../protocol/share_peer.dart';
import '../protocol/share_routes.dart';
import '../store/share_records.dart';
import 'share_http.dart';
import 'share_server_context.dart';

/// `POST /abx/v1/pair` — held open until the user answers.
///
/// A device id that is already paired is asked about again and gets a NEW
/// token. Handing back the stored one would give it to anybody who claims
/// that id.
Future<void> handleSharePair(
  ShareServerContext ctx,
  HttpRequest request,
) async {
  final ip = request.connectionInfo?.remoteAddress.address ?? '';
  final peer = SharePeer.fromJson(
    await readShareJson(request, ShareLimits.pairBodyBytes),
    ip: ip,
  );
  if (peer == null || peer.deviceId == ctx.self().deviceId) {
    return replyShareError(request, HttpStatus.badRequest, 'bad_request');
  }

  final known = await ctx.store.device(peer.deviceId);
  if (known?.blocked ?? false) {
    return replyShareError(request, HttpStatus.forbidden, 'blocked');
  }
  if (ctx.pendingPairs.contains(peer.deviceId) ||
      ctx.pendingPairs.length >= ShareLimits.maxPendingPairs) {
    return replyShareError(request, HttpStatus.tooManyRequests, 'busy');
  }

  ctx.pendingPairs.add(peer.deviceId);
  bool? accepted;
  try {
    accepted = await ctx
        .onPairRequest(peer)
        .timeout(ShareLimits.pairAnswerTimeout);
  } catch (_) {
    accepted = null;
  } finally {
    ctx.pendingPairs.remove(peer.deviceId);
  }

  if (accepted == null) {
    return replyShareError(request, HttpStatus.requestTimeout, 'timeout');
  }
  if (!accepted) {
    return replyShareError(request, HttpStatus.forbidden, 'declined');
  }

  final token = newPairToken();
  await ctx.store.saveDevice(
    ShareDeviceRecord(
      deviceId: peer.deviceId,
      name: peer.name,
      deviceType: peer.deviceType,
      userId: peer.userId,
      pairToken: token,
      lastIp: ip,
      lastPort: peer.port,
      lastSeenMs: DateTime.now().millisecondsSinceEpoch,
    ),
  );
  ctx.onPaired?.call(peer.deviceId);
  await replyShare(request, HttpStatus.ok, {'pair_token': token});
}
