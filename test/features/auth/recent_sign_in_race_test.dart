import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:ababilx/core/constants/api_constants.dart';
import 'package:ababilx/core/network/api_client.dart';
import 'package:ababilx/core/network/recent_sign_in.dart';
import 'package:ababilx/core/storage/secure_storage.dart';
import 'package:ababilx/features/auth/data/auth_session.dart';
import 'package:ababilx/features/auth/reauth/recent_sign_in.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records every request; answers each with `{success: true}`.
class _Recorder implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'success': true}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _owner = 'user-1';

/// A token refresh that read the old token before the sign-in wrote, and
/// lands after it: the old session's rotated tokens go back into storage.
Future<void> Function() _lateRefresh(SecureStorage storage) => () async {
  await storage.writeRefreshToken('old-rotated');
  await storage.writeJwt('old-rotated-access');
};

void main() {
  late SecureStorage storage;
  late _Recorder http;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    storage = const SecureStorage(FlutterSecureStorage());
    await storage.writeLocalDataOwnerUserId(_owner);
    await storage.writeJwt('old-access');
    await storage.writeRefreshToken('old-refresh');
    http = _Recorder();
  });

  RecentSignIn reauth({required Future<void> Function() settled}) =>
      RecentSignIn(
        storage: storage,
        bareDio: Dio(BaseOptions(baseUrl: 'https://example.test'))
          ..httpClientAdapter = http,
        keyRelogin: () async {
          await storage.writeRefreshToken('key-refresh');
          await storage.writeJwt('key-access');
          return RefreshOutcome.refreshed;
        },
        googleSignIn: () async => const PreparedAuthSession(
          accessToken: 'new-access',
          refreshToken: 'new-refresh',
          userId: _owner,
          user: {'id': _owner},
        ),
        accountProvider: () async => 'google',
        refreshSettled: settled,
      );

  List<String?> retired() => [
    for (final r in http.requests)
      if (r.path == ApiConstants.authLogout) (r.data as Map)['refresh_token'],
  ];

  test('a refresh landing after a Google sign-in keeps the old session '
      'alive instead of signing the phone out', () async {
    final service = reauth(settled: _lateRefresh(storage));
    expect(await service.reauthenticate(), ReauthOutcome.signedIn);
    expect(retired(), isEmpty, reason: 'ending it would end what is stored');
    expect(await storage.readRefreshToken(), 'old-rotated');
  });

  test('the same race on a key-only account ends nothing either', () async {
    await storage.writeAccountKey('seed');
    final service = reauth(settled: _lateRefresh(storage));
    expect(await service.reauthenticate(), ReauthOutcome.signedIn);
    expect(retired(), isEmpty);
    expect(await storage.readAccountKey(), 'seed');
  });

  test('waits for a running refresh before ending the old session', () async {
    final asked = Completer<void>();
    final gate = Completer<void>();
    final result = reauth(
      settled: () {
        asked.complete();
        return gate.future;
      },
    ).reauthenticate();
    await asked.future;
    expect(retired(), isEmpty, reason: 'nothing ended while a refresh runs');
    gate.complete();
    expect(await result, ReauthOutcome.signedIn);
    expect(retired(), ['old-refresh']);
  });

  test('a refresh that failed still lets the old session be ended', () async {
    final service = reauth(settled: () async => throw StateError('refresh'));
    expect(await service.reauthenticate(), ReauthOutcome.signedIn);
    expect(retired(), ['old-refresh']);
    expect(await storage.readRefreshToken(), 'new-refresh');
  });
}
