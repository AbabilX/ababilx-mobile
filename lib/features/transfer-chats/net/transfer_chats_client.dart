import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../wire/transfer_chats_wire.dart';

class TransferUnreachable implements Exception {
  const TransferUnreachable();
}

class TransferRefused implements Exception {
  const TransferRefused(this.status);
  final int status;
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

  void close() => _http.close(force: true);
}
