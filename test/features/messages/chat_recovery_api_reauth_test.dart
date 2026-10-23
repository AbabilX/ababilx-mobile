import 'dart:convert';
import 'dart:typed_data';

import 'package:ababilx/core/network/api_client.dart';
import 'package:ababilx/core/network/recent_sign_in.dart';
import 'package:ababilx/core/storage/secure_storage.dart';
import 'package:ababilx/features/messages/data/chat_recovery_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers from a list of statuses; remembers each body it was sent.
class _Scripted implements HttpClientAdapter {
  _Scripted(this.statuses);
  final List<int> statuses;
  final bodies = <Object?>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    bodies.add(options.data);
    final status = statuses[bodies.length - 1];
    final body = status == 200
        ? {'success': true}
        : {'success': false, 'error': recentSignInRequiredCode};
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  final body = {
    'public_key': {'x': 'new', 'y': 'new'},
    'expected_public_key': {'x': 'old', 'y': 'old'},
    'clear_history': true,
  };

  ApiClient clientWith(_Scripted http) {
    FlutterSecureStorage.setMockInitialValues({});
    return ApiClient(const SecureStorage(FlutterSecureStorage()))
      ..dio.httpClientAdapter = http;
  }

  test('signs in again and sends the same body once more', () async {
    final http = _Scripted([403, 200]);
    var signIns = 0;
    final api = ChatRecoveryApi(clientWith(http), () async {
      signIns++;
      return ReauthOutcome.signedIn;
    });
    await api.startSession(body);
    expect(signIns, 1);
    expect(http.bodies, hasLength(2));
    expect(jsonEncode(http.bodies[1]), jsonEncode(http.bodies[0]));
  });

  test('a second refusal is reported, never retried again', () async {
    final http = _Scripted([403, 403, 200]);
    var signIns = 0;
    final api = ChatRecoveryApi(clientWith(http), () async {
      signIns++;
      return ReauthOutcome.signedIn;
    });
    await expectLater(
      api.startSession(body),
      throwsA(isA<RecentSignInRequired>()),
    );
    expect(signIns, 1);
    expect(http.bodies, hasLength(2));
  });

  test('a failed sign-in sends nothing more', () async {
    final http = _Scripted([403, 200]);
    final api = ChatRecoveryApi(
      clientWith(http),
      () async => ReauthOutcome.failed,
    );
    await expectLater(
      api.startSession(body),
      throwsA(
        isA<RecentSignInRequired>().having(
          (e) => e.outcome,
          'outcome',
          ReauthOutcome.failed,
        ),
      ),
    );
    expect(http.bodies, hasLength(1));
  });
}
