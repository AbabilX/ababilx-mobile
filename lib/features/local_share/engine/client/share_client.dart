import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../protocol/share_envelope.dart';
import '../protocol/share_file.dart';
import '../protocol/share_peer.dart';
import '../protocol/share_routes.dart';
import '../share_progress.dart';
import 'share_endpoint.dart';
import 'share_upload.dart';

/// Outcome of asking a device to pair. [token] is set only on Accept.
class SharePairResult {
  const SharePairResult({this.token, this.error});

  final String? token;

  /// `declined`, `blocked`, `timeout`, `busy` or `unreachable`.
  final String? error;
}

/// The send side of `abx-share/1`. Holds no state between calls.
class ShareClient {
  ShareClient(this.progress, {HttpClient? http})
    : _http = http ?? (HttpClient()..connectionTimeout = _connect);

  static const _connect = Duration(seconds: 5);
  static const _answer = Duration(seconds: 15);

  final ShareProgressHub progress;
  final HttpClient _http;

  /// `GET /info`; null when nothing AbabilX answers there.
  Future<SharePeer?> info(
    String ip,
    int port, {
    Duration timeout = const Duration(milliseconds: 700),
  }) async {
    try {
      final request = await _http
          .getUrl(Uri.parse('http://$ip:$port${ShareRoutes.info}'))
          .timeout(timeout);
      final response = await request.close().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        return null;
      }
      final body = await utf8.decoder.bind(response).join().timeout(timeout);
      return SharePeer.fromJson(jsonDecode(body), ip: ip);
    } catch (_) {
      return null;
    }
  }

  /// Waits for the other user's answer (up to the receiver's 60 s).
  Future<SharePairResult> pair(String ip, int port, SharePeer self) async {
    try {
      final (status, json) = await _post(
        Uri.parse('http://$ip:$port${ShareRoutes.pair}'),
        self.encode(announce: false),
        timeout: ShareLimits.pairAnswerTimeout + const Duration(seconds: 10),
      );
      final token = json['pair_token'];
      if (status == HttpStatus.ok && token is String && token.length >= 32) {
        return SharePairResult(token: token);
      }
      final error = json['error'];
      return SharePairResult(error: error is String ? error : 'unreachable');
    } catch (_) {
      return const SharePairResult(error: 'unreachable');
    }
  }

  /// Posts the envelope, then every file the receiver does not have in full.
  /// [paths] maps file id to where its bytes are on this device.
  Future<ShareSendResult> send(
    ShareEndpoint to,
    ShareEnvelope envelope,
    Map<String, String> paths, {
    ShareCancel? cancel,
  }) async {
    final Map<String, dynamic> upload;
    try {
      final (status, json) = await _post(
        to.uri(ShareRoutes.messages),
        envelope.encode(),
        sign: to,
      );
      if (status == HttpStatus.unauthorized) {
        return const ShareSendResult(ShareSendOutcome.unpaired);
      }
      if (status == HttpStatus.gone) {
        return const ShareSendResult(ShareSendOutcome.canceled);
      }
      final raw = json['upload'];
      if (status != HttpStatus.ok || raw is! Map<String, dynamic>) {
        return const ShareSendResult(ShareSendOutcome.incomplete);
      }
      upload = raw;
    } catch (_) {
      return const ShareSendResult(ShareSendOutcome.unreachable);
    }

    final done = <String>{};
    final small = <ShareFile>[];
    final large = <ShareFile>[];
    for (final file in envelope.files) {
      final have = upload[file.id];
      if (have is int && have >= file.size) {
        done.add(file.id);
      } else if (file.size < ShareLimits.smallFileBytes) {
        small.add(file);
      } else {
        large.add(file);
      }
    }

    ShareUploadOutcome? stop;
    Future<void> run(ShareFile file) async {
      if (stop != null) return;
      final have = upload[file.id];
      final outcome = await uploadShareFile(
        http: _http,
        to: to,
        messageId: envelope.id,
        fileId: file.id,
        path: paths[file.id] ?? '',
        size: file.size,
        offset: have is int && have > 0 ? have : 0,
        progress: progress,
        cancel: cancel,
      );
      if (outcome == ShareUploadOutcome.done) {
        done.add(file.id);
      } else if (outcome != ShareUploadOutcome.failed) {
        stop ??= outcome;
      }
    }

    // Small files three at a time (the handshake dominates them); large ones
    // alone, so they do not split the link between them.
    final queue = List.of(small);
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        await run(queue.removeAt(0));
      }
    }

    await Future.wait([
      for (var i = 0; i < ShareLimits.smallFileParallelism; i++) worker(),
    ]);
    for (final file in large) {
      await run(file);
    }

    final outcome = switch (stop) {
      ShareUploadOutcome.unpaired => ShareSendOutcome.unpaired,
      ShareUploadOutcome.canceled => ShareSendOutcome.canceled,
      _ =>
        done.length == envelope.files.length
            ? ShareSendOutcome.done
            : ShareSendOutcome.incomplete,
    };
    return ShareSendResult(outcome, doneFileIds: done);
  }

  /// Tells the receiver to drop a message it is still receiving.
  Future<void> cancel(ShareEndpoint to, String messageId) async {
    try {
      await _post(to.uri(ShareRoutes.cancel(messageId)), '', sign: to);
    } catch (_) {}
  }

  Future<(int, Map<String, dynamic>)> _post(
    Uri uri,
    String body, {
    ShareEndpoint? sign,
    Duration timeout = _answer,
  }) async {
    final request = await _http.postUrl(uri).timeout(_connect);
    sign?.sign(request);
    request.headers.contentType = ContentType.json;
    request.add(utf8.encode(body));
    final response = await request.close().timeout(timeout);
    final text = await utf8.decoder.bind(response).join().timeout(timeout);
    Object? json;
    try {
      json = jsonDecode(text);
    } catch (_) {}
    return (
      response.statusCode,
      json is Map<String, dynamic> ? json : <String, dynamic>{},
    );
  }

  void close() => _http.close(force: true);
}
