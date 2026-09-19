import 'dart:convert';
import 'dart:typed_data';

import 'package:ababilx/core/network/api_client.dart';
import 'package:ababilx/core/storage/secure_storage.dart';
import 'package:ababilx/features/auth/email/email_auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with one canned response and remembers the request.
class _Canned implements HttpClientAdapter {
  _Canned(this.status, this.body);

  final int status;
  final Map<String, dynamic> body;
  RequestOptions? last;
  Map<String, dynamic>? sent;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    sent = options.data is Map ? Map<String, dynamic>.from(options.data) : null;
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
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  (EmailAuthRepository, _Canned) build(int status, Map<String, dynamic> body) {
    final client = ApiClient(const SecureStorage(FlutterSecureStorage()));
    final adapter = _Canned(status, body);
    client.dio.httpClientAdapter = adapter;
    return (EmailAuthRepository(client), adapter);
  }

  test('a sign-in answer becomes a session, sent as the mobile client', () async {
    final (repo, adapter) = build(200, {
      'success': true,
      'access_token': 'a',
      'refresh_token': 'r',
      'user': {'id': 'u1', 'email': 'me@example.com'},
    });
    final session = await repo.signIn(email: 'me@example.com', password: 'pw');
    expect(session.accessToken, 'a');
    expect(session.refreshToken, 'r');
    expect(session.userId, 'u1');
    expect(adapter.last!.path, '/auth/email/login');
    expect(adapter.sent!['client'], 'mobile');
  });

  test('a structured refusal carries its code and wait', () async {
    final (repo, _) = build(429, {
      'success': false,
      'code': 'code_cooldown',
      'message': 'A code was just sent',
      'retry_after': 42,
    });
    await expectLater(
      repo.requestReset(email: 'me@example.com'),
      throwsA(
        isA<EmailAuthException>()
            .having((e) => e.code, 'code', 'code_cooldown')
            .having((e) => e.retryAfter, 'wait', const Duration(seconds: 42)),
      ),
    );
  });

  test('a wrong password does not touch the stored session', () async {
    final (repo, _) = build(401, {
      'success': false,
      'code': 'invalid_credentials',
      'message': 'Email or password is wrong.',
    });
    await expectLater(
      repo.signIn(email: 'me@example.com', password: 'nope'),
      throwsA(
        isA<EmailAuthException>().having(
          (e) => e.code,
          'code',
          'invalid_credentials',
        ),
      ),
    );
  });

  test('a code request reports where it went', () async {
    final (repo, adapter) = build(200, {
      'success': true,
      'data': {'email': 'me****@example.com', 'resend_in': 60},
    });
    final sent = await repo.signUp(
      name: 'Me',
      email: 'me@example.com',
      password: 'longenough',
    );
    expect(sent.maskedEmail, 'me****@example.com');
    expect(sent.resendIn, const Duration(seconds: 60));
    expect(adapter.last!.path, '/auth/email/signup');
  });
}
