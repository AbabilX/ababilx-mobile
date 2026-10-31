import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Answers Dio requests from a handler: (options) -> (status, json body).
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  (int, Object?) Function(RequestOptions o) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    requests.add(o);
    final (code, json) = handler(o);
    return ResponseBody.fromString(
      jsonEncode(json),
      code,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> ok(Object? data) => {'success': true, 'data': data};
