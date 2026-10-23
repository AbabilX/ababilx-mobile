import 'dart:async';
import 'dart:convert';

import 'package:ababilx/core/constants/api_constants.dart';
import 'package:ababilx/core/network/api_client.dart';
import 'package:ababilx/core/network/recent_sign_in.dart';
import 'package:ababilx/core/storage/secure_storage.dart';
import 'package:ababilx/features/auth/data/auth_session.dart';
import 'package:ababilx/features/auth/reauth/recent_sign_in.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
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

PreparedAuthSession _session(String userId, {String refresh = 'new-refresh'}) =>
    PreparedAuthSession(
      accessToken: 'new-access',
      refreshToken: refresh,
      userId: userId,
      user: {'id': userId},
    );

void main() {
  late SecureStorage storage;
  late _Recorder http;
  late Dio dio;
  var keyLogins = 0;
  var googleLogins = 0;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    storage = const SecureStorage(FlutterSecureStorage());
    await storage.writeLocalDataOwnerUserId(_owner);
    await storage.writeJwt('old-access');
    await storage.writeRefreshToken('old-refresh');
    await storage.writeMessageVaultIdentity('identity-sentinel');
    await storage.writePendingRecovery(_owner, 'pending-sentinel');
    http = _Recorder();
    dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = http;
    keyLogins = 0;
    googleLogins = 0;
  });

  RecentSignIn reauth({
    RefreshOutcome key = RefreshOutcome.refreshed,
    FutureOr<PreparedAuthSession?> Function()? google,
    String provider = 'google',
  }) => RecentSignIn(
    storage: storage,
    bareDio: dio,
    keyRelogin: () async {
      keyLogins++;
      if (key == RefreshOutcome.refreshed) {
        await storage.writeRefreshToken('key-refresh');
        await storage.writeJwt('key-access');
      }
      return key;
    },
    googleSignIn: () async {
      googleLogins++;
      return google == null ? _session(_owner) : await google();
    },
    accountProvider: () async => provider,
  );

  List<String?> retired() => [
    for (final r in http.requests)
      if (r.path == ApiConstants.authLogout) (r.data as Map)['refresh_token'],
  ];

  Future<void> expectIdentityUntouched() async {
    expect(await storage.readMessageVaultIdentity(), 'identity-sentinel');
    expect(await storage.readPendingRecovery(_owner), 'pending-sentinel');
  }

  group('key-only account (Start New Chat)', () {
    setUp(() => storage.writeAccountKey('seed'));

    test('signs in with its key and retires the old session', () async {
      expect(await reauth().reauthenticate(), ReauthOutcome.signedIn);
      expect(keyLogins, 1);
      expect(googleLogins, 0, reason: 'never shows Google to a key account');
      expect(await storage.readJwt(), 'key-access');
      expect(retired(), ['old-refresh']);
      expect(await storage.readAccountKey(), 'seed');
      await expectIdentityUntouched();
    });

    test('a refused key sign-in fails and changes nothing', () async {
      final outcome = await reauth(
        key: RefreshOutcome.rejected,
      ).reauthenticate();
      expect(outcome, ReauthOutcome.failed);
      expect(await storage.readJwt(), 'old-access');
      expect(retired(), isEmpty);
      await expectIdentityUntouched();
    });

    test('offline is unavailable, not a refusal', () async {
      final outcome = await reauth(
        key: RefreshOutcome.unavailable,
      ).reauthenticate();
      expect(outcome, ReauthOutcome.unavailable);
      expect(retired(), isEmpty);
    });
  });

  group('Google account', () {
    test('same account: new tokens stored, old session retired', () async {
      expect(await reauth().reauthenticate(), ReauthOutcome.signedIn);
      expect(await storage.readJwt(), 'new-access');
      expect(await storage.readRefreshToken(), 'new-refresh');
      expect(retired(), ['old-refresh']);
      await expectIdentityUntouched();
    });

    test('another account is refused and its new session ended', () async {
      final outcome = await reauth(
        google: () => _session('someone-else', refresh: 'intruder-refresh'),
      ).reauthenticate();
      expect(outcome, ReauthOutcome.failed);
      expect(await storage.readJwt(), 'old-access');
      expect(await storage.readRefreshToken(), 'old-refresh');
      expect(await storage.readLocalDataOwnerUserId(), _owner);
      expect(retired(), ['intruder-refresh']);
      await expectIdentityUntouched();
    });

    test('closing the picker is cancelled and changes nothing', () async {
      final outcome = await reauth(google: () => null).reauthenticate();
      expect(outcome, ReauthOutcome.cancelled);
      expect(await storage.readJwt(), 'old-access');
      expect(retired(), isEmpty);
      await expectIdentityUntouched();
    });

    test('the plugin reporting a cancel is cancelled too', () async {
      final outcome = await reauth(
        google: () => throw PlatformException(code: 'sign_in_canceled'),
      ).reauthenticate();
      expect(outcome, ReauthOutcome.cancelled);
    });

    test('two refusals at once ask the person once', () async {
      final gate = Completer<PreparedAuthSession?>();
      final service = reauth(google: () => gate.future);
      final first = service.reauthenticate();
      final second = service.reauthenticate();
      gate.complete(_session(_owner));
      expect(await first, ReauthOutcome.signedIn);
      expect(await second, ReauthOutcome.signedIn);
      expect(googleLogins, 1);
    });
  });

  test('an email account is not signed in behind its back', () async {
    final outcome = await reauth(provider: 'email').reauthenticate();
    expect(outcome, ReauthOutcome.notSupported);
    expect(googleLogins, 0);
    expect(keyLogins, 0);
    expect(await storage.readJwt(), 'old-access');
    await expectIdentityUntouched();
  });
}
