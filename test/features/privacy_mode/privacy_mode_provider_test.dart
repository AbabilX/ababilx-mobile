import 'dart:async';

import 'package:ababilx/core/network/api_client.dart';
import 'package:ababilx/features/auth/providers/auth_provider.dart';
import 'package:ababilx/features/privacy-mode/privacy_mode_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The server's switch, answered on demand so a test decides when a GET or
/// PUT reply lands.
class _FakeApi implements ApiClient {
  _FakeApi(this.server);

  bool server;
  Completer<void>? holdGet;
  Completer<void>? holdPut;

  Response<T> _answer<T>(String path) => Response<T>(
    requestOptions: RequestOptions(path: path),
    data:
        {
              'data': {'enabled': server},
            }
            as T,
  );

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    final snapshot = server;
    await holdGet?.future;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data:
          {
                'data': {'enabled': snapshot},
              }
              as T,
    );
  }

  @override
  Future<Response<T>> put<T>(String path, {dynamic data}) async {
    server = (data as Map)['enabled'] as bool;
    await holdPut?.future;
    return _answer<T>(path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _container(_FakeApi api) {
  final c = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      isAuthenticatedProvider.overrideWithValue(true),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('resolve follows a toggle made after the first load', () async {
    final api = _FakeApi(false);
    final c = _container(api);
    final notifier = c.read(privacyModeProvider.notifier);

    expect(await notifier.resolve(), isFalse);
    expect(await notifier.set(true), isTrue);
    // The bug: resolve() answered with the first load's frozen result, so
    // the photo sheet stayed off until the app restarted.
    expect(await notifier.resolve(), isTrue);

    expect(await notifier.set(false), isTrue);
    expect(await notifier.resolve(), isFalse);
  });

  test('a slow first load cannot undo a toggle made meanwhile', () async {
    final api = _FakeApi(false)..holdGet = Completer<void>();
    final c = _container(api);
    final notifier = c.read(privacyModeProvider.notifier);

    await notifier.set(true);
    api.holdGet!.complete(); // the stale GET (said "off") lands now
    expect(await notifier.resolve(), isTrue);
    expect(c.read(privacyModeProvider), isTrue);
  });

  test('an older PUT reply cannot undo a newer toggle', () async {
    final api = _FakeApi(false);
    final c = _container(api);
    final notifier = c.read(privacyModeProvider.notifier);
    await notifier.resolve();

    final hold = api.holdPut = Completer<void>();
    final first = notifier.set(true);
    api.holdPut = null;
    await notifier.set(false);
    // The first PUT's reply arrives last and says "on"; it must not win
    // over the newer toggle.
    api.server = true;
    hold.complete();
    await first;
    expect(c.read(privacyModeProvider), isFalse);
  });

  test('another device flipping it moves resolve too', () async {
    final api = _FakeApi(false);
    final c = _container(api);
    final notifier = c.read(privacyModeProvider.notifier);
    await notifier.resolve();

    notifier.applyRemote(true);
    expect(await notifier.resolve(), isTrue);
  });
}
