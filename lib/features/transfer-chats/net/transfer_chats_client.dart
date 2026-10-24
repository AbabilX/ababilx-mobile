import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../wire/transfer_chats_wire.dart';

class TransferUnreachable implements Exception {
  const TransferUnreachable();
}

class TransferRefused implements Exception {
  const TransferRefused(this.status, [this.code = '']);
  final int status;

  /// The server's own reason, when it gave one (`other_account`).
  final String code;
}

/// The old device's side: talks to the address the code named.
class TransferChatsClient {
  TransferChatsClient._(this._http, this._base, this._token);

  final HttpClient _http;
  final Uri _base;
  final String _token;

  /// The first of [addresses] that answers with its status. Throws
  /// [TransferUnreachable] when none does — the two devices are not on the
  /// same network, or the new one closed its screen.
  static Future<TransferChatsClient> reach(
    List<String> addresses,
    String token,
  ) async {
    for (final address in addresses) {
      final http = HttpClient()
        ..connectionTimeout = const Duration(seconds: 4)
        ..idleTimeout = const Duration(seconds: 30);
      final client = TransferChatsClient._(
        http,
        Uri.parse('http://$address'),
        token,
      );
      try {
        await client.status().timeout(const Duration(seconds: 6));
        return client;
      } catch (_) {
        http.close(force: true);
      }
    }
    throw const TransferUnreachable();
  }

  Future<HttpClientRequest> _open(String method, String path) async {
    final request = await _http.openUrl(method, _base.replace(path: path));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
    return request;
  }

  Future<TransferStatus> status() async {
    final request = await _open('GET', transferPathStatus);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != HttpStatus.ok) {
      throw TransferRefused(response.statusCode);
    }
    return TransferStatus.fromJson(
      Map<String, dynamic>.from(jsonDecode(body) as Map),
    );
  }

  Future<void> sendIdentity(Map<String, dynamic> envelope) async {
    final request = await _open('POST', transferPathIdentity);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(envelope));
    final response = await request.close();
    await response.drain<void>();
    if (response.statusCode != HttpStatus.ok) {
      throw TransferRefused(response.statusCode);
    }
  }

  /// The request the backup stream is written into. Chunked: nobody knows
  /// its size until the last record. Finish with [finishStream].
  Future<HttpClientRequest> openStream() async {
    final request = await _open('PUT', transferPathStream);
    request.headers.contentType = ContentType.binary;
    request.bufferOutput = false;
    return request;
  }

  /// Call after the writer closed the request.
  Future<void> finishStream(HttpClientRequest request) async {
    final response = await request.done;
    await response.drain<void>();
    if (response.statusCode != HttpStatus.ok) {
      throw TransferRefused(response.statusCode);
    }
  }

  /// Pull mode: who this phone is -> the message key sealed to [linkKey].
  Future<Map<String, dynamic>> hello(Map<String, dynamic> body) async {
    final request = await _open('POST', transferPathHello);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    final json = _json(text);
    if (response.statusCode != HttpStatus.ok) {
      throw TransferRefused(
        response.statusCode,
        json['error'] as String? ?? '',
      );
    }
    return Map<String, dynamic>.from(json['envelope'] as Map);
  }

  /// Pull mode: the stream into [file]. A stream the computer broke off
  /// (a failed export) throws here, never lands as a short file.
  Future<void> pullStream(File file, void Function(int bytes) onBytes) async {
    final request = await _open('GET', transferPathStream);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw TransferRefused(response.statusCode);
    }
    final sink = file.openWrite();
    var bytes = 0;
    try {
      await sink.addStream(
        response.map((chunk) {
          bytes += chunk.length;
          onBytes(bytes);
          return chunk;
        }),
      );
    } finally {
      await sink.close();
    }
  }

  /// Pull mode: this phone's own progress, so the computer can say when it
  /// is done and offer to delete its copy. Best effort.
  Future<void> report(TransferStatus status) async {
    try {
      final request = await _open('POST', transferPathReport);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(status.toJson()));
      await (await request.close()).drain<void>();
    } catch (_) {}
  }

  static Map<String, dynamic> _json(String text) {
    try {
      return Map<String, dynamic>.from(jsonDecode(text) as Map);
    } catch (_) {
      return const {};
    }
  }

  void close() => _http.close(force: true);
}
